#!/usr/bin/env bash
# autoscaler.sh – Main orchestration loop for the Ganz WNXT autoscaler
# ---------------------------------------------------------------------
# Usage:
#   autoscaler.sh [--once] [--config <path>]
#
# Options:
#   --once        Run a single evaluation pass instead of looping forever.
#   --config      Path to the autoscaler configuration file.
#                 Defaults to ../config/autoscaler.conf relative to this script.
#
# The autoscaler evaluates metrics every METRICS_INTERVAL seconds and scales
# up or down according to the thresholds defined in autoscaler.conf.
# ---------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse --config early so we can source the right file
_ONCE=false
_CONFIG="${SCRIPT_DIR}/../config/autoscaler.conf"

for _arg in "$@"; do
    case "${_arg}" in
        --once)   _ONCE=true ;;
        --config) _CONFIG="$2" ;;
    esac
done

CONFIG_FILE="${_CONFIG}"
export CONFIG_FILE

# shellcheck disable=SC1090
[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"

source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/metrics.sh"
source "${SCRIPT_DIR}/scale_up.sh"
source "${SCRIPT_DIR}/scale_down.sh"
source "${SCRIPT_DIR}/health_check.sh"

# ---------------------------------------------------------------------------
# Single evaluation pass
# ---------------------------------------------------------------------------

evaluate() {
    log_info "--- Autoscaler evaluation pass ---"

    # 1. Collect metrics
    local raw_metrics
    raw_metrics="$(collect_metrics)"

    local cpu_pct mem_pct conn_count
    IFS=$'\t' read -r cpu_pct mem_pct conn_count <<< "${raw_metrics}"

    log_info "Metrics: cpu=${cpu_pct}% mem=${mem_pct}% connections=${conn_count}"

    # 2. Determine scaling action
    local action="none"

    # Scale-up check (any metric over threshold)
    if (( cpu_pct  >= CPU_SCALE_UP_THRESHOLD ))       || \
       (( mem_pct  >= MEMORY_SCALE_UP_THRESHOLD ))    || \
       (( conn_count >= CONNECTION_SCALE_UP_THRESHOLD )); then
        action="up"
    # Scale-down check (ALL metrics below threshold)
    elif (( cpu_pct  < CPU_SCALE_DOWN_THRESHOLD ))    && \
         (( mem_pct  < MEMORY_SCALE_DOWN_THRESHOLD )) && \
         (( conn_count < CONNECTION_SCALE_DOWN_THRESHOLD )); then
        action="down"
    fi

    log_info "Recommended action: ${action}"

    # 3. Apply action (respecting cooldowns)
    case "${action}" in
        up)
            if is_cooldown_active "UP" "${SCALE_UP_COOLDOWN:-120}"; then
                log_info "Scale-up suppressed by cooldown."
            else
                scale_up "${SCALE_UP_STEP:-2}"
            fi
            ;;
        down)
            if is_cooldown_active "DOWN" "${SCALE_DOWN_COOLDOWN:-300}"; then
                log_info "Scale-down suppressed by cooldown."
            else
                scale_down "${SCALE_DOWN_STEP:-1}"
            fi
            ;;
        none)
            log_info "No scaling action required."
            ;;
    esac

    # 4. Health check (runs after scaling so new instances have time to start)
    if ! check_all_instances; then
        log_warn "One or more instances failed the health check."
        send_notification "Ganz WNXT: one or more instances are unhealthy. Manual investigation may be required."
    fi
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

main() {
    local once=false
    local config="${SCRIPT_DIR}/../config/autoscaler.conf"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --once)   once=true; shift ;;
            --config) config="$2"; shift 2 ;;
            *) log_error "Unknown argument: $1"; exit 1 ;;
        esac
    done

    log_info "Ganz WNXT Autoscaler starting. Provider=${PROVIDER:-custom} Interval=${METRICS_INTERVAL:-30}s"
    state_init

    if [[ "${once}" == "true" ]]; then
        evaluate
    else
        while true; do
            evaluate
            log_info "Sleeping ${METRICS_INTERVAL:-30}s until next evaluation."
            sleep "${METRICS_INTERVAL:-30}"
        done
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
