#!/usr/bin/env bash
# health_check.sh – Verify liveness and readiness of Ganz WNXT instances
# -----------------------------------------------------------------------
# Usage:  health_check.sh [--instance <host>] [--all]
#
# Exit codes:
#   0  All checked instances are healthy
#   1  One or more instances are unhealthy
# -----------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/../config/autoscaler.conf}"

# shellcheck disable=SC1090
[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/metrics.sh"

# ---------------------------------------------------------------------------
# Check a single instance
# ---------------------------------------------------------------------------

check_instance() {
    local host="$1"
    local port="${HEALTH_CHECK_PORT:-8080}"
    local endpoint="${HEALTH_CHECK_ENDPOINT:-/health}"
    local timeout="${HEALTH_CHECK_TIMEOUT:-10}"
    local retries="${HEALTH_CHECK_RETRIES:-3}"

    require_commands curl

    local attempt=0
    local http_status=""

    while (( attempt < retries )); do
        (( attempt++ )) || true
        http_status="$(curl --silent --max-time "${timeout}" \
            --output /dev/null \
            --write-out '%{http_code}' \
            "http://${host}:${port}${endpoint}" 2>/dev/null)" || http_status="000"

        if [[ "${http_status}" == "200" ]]; then
            log_debug "Health check PASS for ${host} (attempt ${attempt})"
            return 0
        fi

        log_warn "Health check attempt ${attempt}/${retries} FAIL for ${host} (HTTP ${http_status})"
        (( attempt < retries )) && sleep 2
    done

    log_error "Instance ${host} is UNHEALTHY after ${retries} attempts (last HTTP ${http_status})"
    return 1
}

# ---------------------------------------------------------------------------
# Check all instances
# ---------------------------------------------------------------------------

check_all_instances() {
    mapfile -t hosts < <(list_instances)

    if (( ${#hosts[@]} == 0 )); then
        log_warn "No instances found during health check."
        return 1
    fi

    local healthy=0 unhealthy=0
    for host in "${hosts[@]}"; do
        [[ -z "${host}" ]] && continue
        if check_instance "${host}"; then
            (( healthy++ )) || true
        else
            (( unhealthy++ )) || true
        fi
    done

    log_info "Health check summary: ${healthy} healthy, ${unhealthy} unhealthy (total ${#hosts[@]})"

    (( unhealthy == 0 ))
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

main() {
    local check_all=false
    local target_host=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)              check_all=true; shift ;;
            --instance)         target_host="$2"; shift 2 ;;
            *) log_error "Unknown argument: $1"; exit 1 ;;
        esac
    done

    if [[ "${check_all}" == "true" ]]; then
        check_all_instances
    elif [[ -n "${target_host}" ]]; then
        check_instance "${target_host}"
    else
        # Default: check all instances
        check_all_instances
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
