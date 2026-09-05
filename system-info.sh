#!/usr/bin/env bash
#
# system-info.sh
#
# Collects and displays a snapshot of live system information:
# hostname, current user, date/time, OS, kernel version, uptime,
# CPU info, memory info, and current working directory.
#
# Usage: ./system-info.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/system-info.log"

mkdir -p "${LOG_DIR}"

log() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] $1" >> "${LOG_FILE}"
}

section() {
    printf '\n=== %s ===\n' "$1"
}

log "system-info.sh started"

# ---- Hostname -------------------------------------------------------------
section "Hostname"
hostname

# ---- Current user ----------------------------------------------------------
section "Current User"
whoami

# ---- Date / time ------------------------------------------------------------
section "Date / Time"
date

# ---- Operating system --------------------------------------------------------
section "Operating System"
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${PRETTY_NAME:-${NAME:-Unknown}}"
elif command -v uname >/dev/null 2>&1; then
    uname -s
else
    echo "Unknown"
fi

# ---- Kernel version --------------------------------------------------------
section "Kernel Version"
uname -r

# ---- Uptime -----------------------------------------------------------------
section "Uptime"
if command -v uptime >/dev/null 2>&1; then
    uptime
elif [ -f /proc/uptime ]; then
    awk '{printf "up %.0f seconds\n", $1}' /proc/uptime
else
    echo "Unknown"
fi

# ---- CPU information --------------------------------------------------------
section "CPU Information"
if [ -f /proc/cpuinfo ]; then
    model="$(grep -m1 'model name' /proc/cpuinfo | sed 's/^.*: //')"
    cores="$(grep -c '^processor' /proc/cpuinfo)"
    echo "Model: ${model:-Unknown}"
    echo "Cores: ${cores:-Unknown}"
elif command -v lscpu >/dev/null 2>&1; then
    lscpu
else
    echo "CPU information unavailable"
fi

# ---- Memory information ------------------------------------------------------
section "Memory Information"
if command -v free >/dev/null 2>&1; then
    free -h
elif [ -f /proc/meminfo ]; then
    grep -E '^(MemTotal|MemFree|MemAvailable):' /proc/meminfo
else
    echo "Memory information unavailable"
fi

# ---- Current working directory -----------------------------------------------
section "Current Working Directory"
pwd

log "system-info.sh completed successfully"

exit 0
