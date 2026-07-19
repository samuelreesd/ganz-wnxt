#!/usr/bin/env bash
# utils.sh – Shared utility functions for the Ganz WNXT autoscaler
# -----------------------------------------------------------------------
# Source this file in other scripts: source "$(dirname "$0")/utils.sh"
# -----------------------------------------------------------------------
set -euo pipefail

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "${timestamp} [${level}] ${message}"

    if [[ -n "${LOG_FILE:-}" ]]; then
        mkdir -p "$(dirname "${LOG_FILE}")"
        echo "${timestamp} [${level}] ${message}" >> "${LOG_FILE}"
    fi
}

log_debug() {
    [[ "${LOG_LEVEL:-INFO}" == "DEBUG" ]] && _log "DEBUG" "$@" || true
}

log_info() {
    _log "INFO" "$@"
}

log_warn() {
    _log "WARN" "$@"
}

log_error() {
    _log "ERROR" "$@" >&2
}

# ---------------------------------------------------------------------------
# State file helpers (persist cooldown timestamps and current instance count)
# ---------------------------------------------------------------------------

STATE_DIR="${STATE_DIR:-/var/lib/ganz-wnxt/autoscaler}"
STATE_FILE="${STATE_DIR}/state"

state_init() {
    mkdir -p "${STATE_DIR}"
    if [[ ! -f "${STATE_FILE}" ]]; then
        cat > "${STATE_FILE}" <<EOF
LAST_SCALE_UP=0
LAST_SCALE_DOWN=0
CURRENT_INSTANCES=0
EOF
    fi
}

state_get() {
    local key="$1"
    state_init
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    echo "${!key:-0}"
}

state_set() {
    local key="$1"
    local value="$2"
    state_init

    if grep -q "^${key}=" "${STATE_FILE}" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "${STATE_FILE}"
    else
        echo "${key}=${value}" >> "${STATE_FILE}"
    fi
}

# ---------------------------------------------------------------------------
# Cooldown helpers
# ---------------------------------------------------------------------------

is_cooldown_active() {
    local cooldown_type="$1"   # "UP" or "DOWN"
    local cooldown_seconds="$2"

    local last_event
    last_event="$(state_get "LAST_SCALE_${cooldown_type}")"
    local now
    now="$(date +%s)"
    local elapsed=$(( now - last_event ))

    if (( elapsed < cooldown_seconds )); then
        local remaining=$(( cooldown_seconds - elapsed ))
        log_info "Cooldown active for scale-${cooldown_type,,}. ${remaining}s remaining."
        return 0
    fi
    return 1
}

record_scale_event() {
    local cooldown_type="$1"   # "UP" or "DOWN"
    state_set "LAST_SCALE_${cooldown_type}" "$(date +%s)"
}

# ---------------------------------------------------------------------------
# Notification helper
# ---------------------------------------------------------------------------

send_notification() {
    local message="$1"

    if [[ "${NOTIFY_ON_SCALE:-false}" == "true" && -n "${NOTIFY_WEBHOOK_URL:-}" ]]; then
        local payload
        payload="$(printf '{"text": "%s"}' "${message}")"
        if command -v curl &>/dev/null; then
            curl -s -X POST \
                -H 'Content-Type: application/json' \
                -d "${payload}" \
                "${NOTIFY_WEBHOOK_URL}" || log_warn "Failed to send notification."
        else
            log_warn "curl not available – notification not sent."
        fi
    fi
}

# ---------------------------------------------------------------------------
# Misc helpers
# ---------------------------------------------------------------------------

require_commands() {
    local missing=()
    for cmd in "$@"; do
        if ! command -v "${cmd}" &>/dev/null; then
            missing+=("${cmd}")
        fi
    done
    if (( ${#missing[@]} > 0 )); then
        log_error "Required commands not found: ${missing[*]}"
        exit 1
    fi
}

clamp() {
    local value="$1"
    local min="$2"
    local max="$3"
    if (( value < min )); then
        echo "${min}"
    elif (( value > max )); then
        echo "${max}"
    else
        echo "${value}"
    fi
}
