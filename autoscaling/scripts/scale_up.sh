#!/usr/bin/env bash
# scale_up.sh – Add instances to the Ganz WNXT deployment
# ---------------------------------------------------------
# Usage:  scale_up.sh [--count <n>]
#
# Adds SCALE_UP_STEP instances (or --count if specified) up to MAX_INSTANCES.
# ---------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/../config/autoscaler.conf}"

# shellcheck disable=SC1090
[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/metrics.sh"

# ---------------------------------------------------------------------------
# Provider-specific add-instance implementations
# ---------------------------------------------------------------------------

add_instances_aws() {
    local desired="$1"
    require_commands aws
    log_info "AWS: setting desired capacity to ${desired} for ASG '${AWS_AUTO_SCALING_GROUP}'"
    aws autoscaling set-desired-capacity \
        --region "${AWS_REGION}" \
        --auto-scaling-group-name "${AWS_AUTO_SCALING_GROUP}" \
        --desired-capacity "${desired}"
}

add_instances_gcp() {
    local desired="$1"
    require_commands gcloud
    log_info "GCP: resizing instance group '${GCP_INSTANCE_GROUP}' to ${desired}"
    gcloud compute instance-groups managed resize "${GCP_INSTANCE_GROUP}" \
        --size="${desired}" \
        --zone="${GCP_ZONE}" \
        --project="${GCP_PROJECT}"
}

add_instances_azure() {
    local desired="$1"
    require_commands az
    log_info "Azure: scaling VMSS '${AZURE_VMSS_NAME}' to ${desired} instances"
    az vmss scale \
        --resource-group "${AZURE_RESOURCE_GROUP}" \
        --name "${AZURE_VMSS_NAME}" \
        --new-capacity "${desired}"
}

add_instances_custom() {
    local count="$1"
    if [[ -n "${CUSTOM_ADD_INSTANCE_SCRIPT:-}" && -x "${CUSTOM_ADD_INSTANCE_SCRIPT}" ]]; then
        log_info "Custom: running ${CUSTOM_ADD_INSTANCE_SCRIPT} to add ${count} instance(s)"
        "${CUSTOM_ADD_INSTANCE_SCRIPT}" "${count}"
    else
        log_error "PROVIDER=custom but CUSTOM_ADD_INSTANCE_SCRIPT is not set or not executable."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Main scale-up logic
# ---------------------------------------------------------------------------

scale_up() {
    local add_count="${1:-${SCALE_UP_STEP:-2}}"

    # Current instance count
    mapfile -t current_hosts < <(list_instances)
    local current="${#current_hosts[@]}"
    local desired=$(( current + add_count ))
    desired="$(clamp "${desired}" "${MIN_INSTANCES:-2}" "${MAX_INSTANCES:-20}")"

    if (( desired <= current )); then
        log_info "Already at or above MAX_INSTANCES (${MAX_INSTANCES}). No scale-up performed."
        return 0
    fi

    local actual_add=$(( desired - current ))
    log_info "Scaling UP: ${current} -> ${desired} instances (+${actual_add})"

    case "${PROVIDER:-custom}" in
        aws)    add_instances_aws   "${desired}" ;;
        gcp)    add_instances_gcp   "${desired}" ;;
        azure)  add_instances_azure "${desired}" ;;
        custom) add_instances_custom "${actual_add}" ;;
        *)      log_error "Unknown PROVIDER: ${PROVIDER}"; exit 1 ;;
    esac

    record_scale_event "UP"
    state_set "CURRENT_INSTANCES" "${desired}"

    local msg="Ganz WNXT scaled UP: ${current} -> ${desired} instances"
    log_info "${msg}"
    send_notification "${msg}"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

main() {
    local count="${SCALE_UP_STEP:-2}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --count) count="$2"; shift 2 ;;
            *) log_error "Unknown argument: $1"; exit 1 ;;
        esac
    done
    scale_up "${count}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
