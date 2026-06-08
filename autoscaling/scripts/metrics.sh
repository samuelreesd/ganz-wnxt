#!/usr/bin/env bash
# metrics.sh – Collect CPU, memory and connection metrics from running instances
# -------------------------------------------------------------------------------
# Usage:  metrics.sh [--instance <host>]
#
# When --instance is omitted the script reports aggregated metrics across all
# instances listed by the configured provider.
#
# Output (one line, tab-separated):
#   CPU_PERCENT  MEMORY_PERCENT  ACTIVE_CONNECTIONS
# -------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/../config/autoscaler.conf}"

# shellcheck disable=SC1090
[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"
source "${SCRIPT_DIR}/utils.sh"

# ---------------------------------------------------------------------------
# Collect metrics from a single host
# ---------------------------------------------------------------------------

collect_host_cpu() {
    local host="$1"
    if [[ "${host}" == "localhost" || "${host}" == "127.0.0.1" ]]; then
        # Use /proc/stat for a quick one-second sample
        local cpu1 cpu2
        cpu1="$(grep -m1 '^cpu ' /proc/stat | awk '{idle=$5; total=0; for(i=2;i<=NF;i++) total+=$i; print idle, total}')"
        sleep 1
        cpu2="$(grep -m1 '^cpu ' /proc/stat | awk '{idle=$5; total=0; for(i=2;i<=NF;i++) total+=$i; print idle, total}')"

        local idle1 total1 idle2 total2
        read -r idle1 total1 <<< "${cpu1}"
        read -r idle2 total2 <<< "${cpu2}"

        local delta_total=$(( total2 - total1 ))
        local delta_idle=$(( idle2 - idle1 ))

        if (( delta_total == 0 )); then
            echo 0
        else
            echo $(( 100 * (delta_total - delta_idle) / delta_total ))
        fi
    else
        ssh -o ConnectTimeout=5 -o BatchMode=yes "${host}" \
            'grep -m1 "^cpu " /proc/stat | awk '"'"'{idle=$5; total=0; for(i=2;i<=NF;i++) total+=$i; print idle, total}'"'"' > /tmp/_c1; sleep 1; grep -m1 "^cpu " /proc/stat | awk '"'"'{idle=$5; total=0; for(i=2;i<=NF;i++) total+=$i; print idle, total}'"'"' > /tmp/_c2; read idle1 total1 < /tmp/_c1; read idle2 total2 < /tmp/_c2; dt=$((total2-total1)); di=$((idle2-idle1)); [ "$dt" -eq 0 ] && echo 0 || echo $((100*(dt-di)/dt))' 2>/dev/null || echo 0
    fi
}

collect_host_memory() {
    local host="$1"
    if [[ "${host}" == "localhost" || "${host}" == "127.0.0.1" ]]; then
        awk '/MemTotal/{total=$2} /MemAvailable/{avail=$2} END{printf "%d", (total-avail)*100/total}' /proc/meminfo
    else
        ssh -o ConnectTimeout=5 -o BatchMode=yes "${host}" \
            "awk '/MemTotal/{total=\$2} /MemAvailable/{avail=\$2} END{printf \"%d\", (total-avail)*100/total}' /proc/meminfo" 2>/dev/null || echo 0
    fi
}

collect_host_connections() {
    local host="$1"
    local port="${HEALTH_CHECK_PORT:-8080}"
    if [[ "${host}" == "localhost" || "${host}" == "127.0.0.1" ]]; then
        ss -tn state established "( dport = :${port} or sport = :${port} )" 2>/dev/null | tail -n +2 | wc -l || echo 0
    else
        ssh -o ConnectTimeout=5 -o BatchMode=yes "${host}" \
            "ss -tn state established '( dport = :${port} or sport = :${port} )' 2>/dev/null | tail -n +2 | wc -l" 2>/dev/null || echo 0
    fi
}

# ---------------------------------------------------------------------------
# List instances via configured provider
# ---------------------------------------------------------------------------

list_instances() {
    case "${PROVIDER:-custom}" in
        aws)
            require_commands aws
            aws autoscaling describe-auto-scaling-groups \
                --region "${AWS_REGION}" \
                --auto-scaling-group-names "${AWS_AUTO_SCALING_GROUP}" \
                --query 'AutoScalingGroups[0].Instances[?HealthStatus==`Healthy`].InstanceId' \
                --output text | tr '\t' '\n' | while read -r id; do
                    aws ec2 describe-instances \
                        --region "${AWS_REGION}" \
                        --instance-ids "${id}" \
                        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
                        --output text
                done
            ;;
        gcp)
            require_commands gcloud
            gcloud compute instance-groups managed list-instances \
                "${GCP_INSTANCE_GROUP}" \
                --zone "${GCP_ZONE}" \
                --project "${GCP_PROJECT}" \
                --format='value(instance)' | while read -r name; do
                    gcloud compute instances describe "${name}" \
                        --zone "${GCP_ZONE}" \
                        --project "${GCP_PROJECT}" \
                        --format='value(networkInterfaces[0].networkIP)'
                done
            ;;
        azure)
            require_commands az
            az vmss list-instances \
                --resource-group "${AZURE_RESOURCE_GROUP}" \
                --name "${AZURE_VMSS_NAME}" \
                --query '[].osProfile.computerName' \
                --output tsv
            ;;
        custom)
            if [[ -n "${CUSTOM_LIST_INSTANCES_SCRIPT:-}" && -x "${CUSTOM_LIST_INSTANCES_SCRIPT}" ]]; then
                "${CUSTOM_LIST_INSTANCES_SCRIPT}"
            else
                log_warn "PROVIDER=custom but CUSTOM_LIST_INSTANCES_SCRIPT is not set or not executable."
                echo "localhost"
            fi
            ;;
        *)
            log_error "Unknown PROVIDER: ${PROVIDER}"
            exit 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Aggregate metrics across all instances
# ---------------------------------------------------------------------------

collect_metrics() {
    local target_host="${1:-}"

    if [[ -n "${target_host}" ]]; then
        local hosts=("${target_host}")
    else
        mapfile -t hosts < <(list_instances)
    fi

    if (( ${#hosts[@]} == 0 )); then
        log_warn "No instances found for metrics collection."
        echo "0	0	0"
        return
    fi

    local total_cpu=0 total_mem=0 total_conn=0
    local count=0

    for host in "${hosts[@]}"; do
        [[ -z "${host}" ]] && continue
        local cpu mem conn
        cpu="$(collect_host_cpu "${host}")"
        mem="$(collect_host_memory "${host}")"
        conn="$(collect_host_connections "${host}")"
        log_debug "Host ${host}: cpu=${cpu}% mem=${mem}% conn=${conn}"
        total_cpu=$(( total_cpu + cpu ))
        total_mem=$(( total_mem + mem ))
        total_conn=$(( total_conn + conn ))
        (( count++ )) || true
    done

    if (( count == 0 )); then
        echo "0	0	0"
        return
    fi

    local avg_cpu=$(( total_cpu / count ))
    local avg_mem=$(( total_mem / count ))
    # Connections are summed, not averaged
    echo "${avg_cpu}	${avg_mem}	${total_conn}"
}

# ---------------------------------------------------------------------------
# Entry point (when run directly)
# ---------------------------------------------------------------------------

main() {
    local instance_host=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --instance) instance_host="$2"; shift 2 ;;
            *) log_error "Unknown argument: $1"; exit 1 ;;
        esac
    done

    collect_metrics "${instance_host}"
}

# Run main only when executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
