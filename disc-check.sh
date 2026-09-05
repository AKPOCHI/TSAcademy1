#!/usr/bin/env bash
#
# disk-check.sh
#
# Checks disk usage for a path against a threshold percentage.
#
# Usage: ./disk-check.sh <threshold> [path]
#
#   threshold   integer from 1 to 100 (required)
#   path        path to check (optional, default: /)
#
# Exit codes:
#   0  usage is below the threshold
#   1  usage is at or above the threshold
#   2  invalid input (bad args, bad threshold, bad path)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/disk-check.log"

mkdir -p "${LOG_DIR}"

log() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] $1" >> "${LOG_FILE}"
}

usage() {
    echo "Usage: $0 <threshold> [path]" >&2
    echo "  threshold : integer from 1 to 100" >&2
    echo "  path      : path to check (default: /)" >&2
}

# ---- Help ---------------------------------------------------------------------
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

# ---- Validate arguments -----------------------------------------------------
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
    log "ERROR: invalid number of arguments ($#)"
    exit 2
fi

THRESHOLD="$1"
CHECK_PATH="${2:-/}"

# threshold must be an integer 1-100
if ! [[ "${THRESHOLD}" =~ ^[0-9]+$ ]]; then
    echo "Error: threshold must be an integer." >&2
    usage
    log "ERROR: threshold '${THRESHOLD}' is not an integer"
    exit 2
fi

if [ "${THRESHOLD}" -lt 1 ] || [ "${THRESHOLD}" -gt 100 ]; then
    echo "Error: threshold must be between 1 and 100." >&2
    usage
    log "ERROR: threshold '${THRESHOLD}' out of range (1-100)"
    exit 2
fi

if [ ! -e "${CHECK_PATH}" ]; then
    echo "Error: path '${CHECK_PATH}' does not exist." >&2
    log "ERROR: path '${CHECK_PATH}' does not exist"
    exit 2
fi

# ---- Get disk usage percentage ------------------------------------------------
USAGE_LINE="$(df -P "${CHECK_PATH}" 2>/dev/null | tail -1)"
if [ -z "${USAGE_LINE}" ]; then
    echo "Error: unable to read disk usage for '${CHECK_PATH}'." >&2
    log "ERROR: df failed for path '${CHECK_PATH}'"
    exit 2
fi

USAGE_PERCENT="$(echo "${USAGE_LINE}" | awk '{print $5}' | tr -d '%')"

if ! [[ "${USAGE_PERCENT}" =~ ^[0-9]+$ ]]; then
    echo "Error: could not parse disk usage percentage." >&2
    log "ERROR: could not parse usage percentage from df output"
    exit 2
fi

echo "Path: ${CHECK_PATH}"
echo "Disk usage: ${USAGE_PERCENT}%"
echo "Threshold: ${THRESHOLD}%"

log "Checked '${CHECK_PATH}': usage=${USAGE_PERCENT}%, threshold=${THRESHOLD}%"



# ---- Compare against threshold ------------------------------------------------
if [ "${USAGE_PERCENT}" -ge "${THRESHOLD}" ]; then
    echo "Status: WARNING - usage has reached or exceeded the threshold."
    log "RESULT: usage ${USAGE_PERCENT}% >= threshold ${THRESHOLD}% (exit 1)"
    exit 1
else
    echo "Status: OK - usage is below the threshold."
    log "RESULT: usage ${USAGE_PERCENT}% < threshold ${THRESHOLD}% (exit 0)"
    exit 0
fi

          #----------------------end-----------------------------


