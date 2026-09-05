#!/usr/bin/env bash
#
# network-check.sh
#
# Performs basic network diagnostics for a host, and optionally a port.
#
# Usage: ./network-check.sh <hostname-or-ip> [port]
#
#   hostname-or-ip   required
#   port             optional, must be 1-65535
#
# Behavior:
#   - Validates the host argument.
#   - Resolves the host and displays the resolved address.
#   - Performs a basic connectivity check.
#   - Displays network interface information.
#   - If a port is supplied, checks TCP connectivity to it.
#
# Exit codes:
#   0  all requested checks succeeded
#   1  a requested check failed (e.g. host unreachable, port closed)
#   2  invalid input (missing/bad host, bad port)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/network-check.log"

mkdir -p "${LOG_DIR}"

log() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] $1" >> "${LOG_FILE}"
}

usage() {
    echo "Usage: $0 <hostname-or-ip> [port]" >&2
    echo "  hostname-or-ip : host to check" >&2
    echo "  port           : optional TCP port (1-65535)" >&2
}

STATUS=0

# ---- Help ---------------------------------------------------------------------
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

# ---- Validate host argument --------------------------------------------------
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
    log "ERROR: invalid number of arguments ($#)"
    exit 2
fi

HOST="$1"
PORT="${2:-}"

# Basic sanity check on the host string: no spaces, no shell metacharacters,
# only characters valid in hostnames/IPv4/IPv6 addresses.
if [ -z "${HOST}" ] || [[ "${HOST}" =~ [[:space:]] ]] || ! [[ "${HOST}" =~ ^[A-Za-z0-9.:_-]+$ ]]; then
    echo "Error: '${HOST}' is not a valid hostname or IP address." >&2
    usage
    log "ERROR: invalid host argument '${HOST}'"
    exit 2
fi

# Validate optional port
if [ -n "${PORT}" ]; then
    if ! [[ "${PORT}" =~ ^[0-9]+$ ]] || [ "${PORT}" -lt 1 ] || [ "${PORT}" -gt 65535 ]; then
        echo "Error: port must be an integer between 1 and 65535." >&2
        usage
        log "ERROR: invalid port argument '${PORT}'"
        exit 2
    fi
fi

log "network-check.sh started for host='${HOST}' port='${PORT:-none}'"

# ---- Resolve the host ---------------------------------------------------------
echo "=== Resolving Host ==="
RESOLVED=""
if command -v getent >/dev/null 2>&1; then
    RESOLVED="$(getent hosts "${HOST}" 2>/dev/null | awk '{print $1}' | head -1)"
fi
if [ -z "${RESOLVED}" ] && command -v python3 >/dev/null 2>&1; then
    RESOLVED="$(python3 - "${HOST}" <<'PYEOF' 2>/dev/null
import socket, sys
try:
    print(socket.gethostbyname(sys.argv[1]))
except Exception:
    pass
PYEOF
)"
fi

if [ -n "${RESOLVED}" ]; then
    echo "Host: ${HOST}"
    echo "Resolved address: ${RESOLVED}"
    log "RESOLVE OK: '${HOST}' -> '${RESOLVED}'"
else
    echo "Host: ${HOST}"
    echo "Resolved address: UNRESOLVED"
    log "RESOLVE FAILED: could not resolve '${HOST}'"
    STATUS=1
fi

# ---- Basic connectivity check (ping) -------------------------------------------
echo
echo "=== Connectivity Check ==="
PING_OK=0
if command -v ping >/dev/null 2>&1; then
    if ping -c 2 -W 2 "${HOST}" >/dev/null 2>&1; then
        PING_OK=1
    fi
elif command -v python3 >/dev/null 2>&1 && [ -n "${RESOLVED}" ]; then
    # Fallback when ping is unavailable: try a raw TCP connect to a common
    # port (443, then 80) purely as a reachability signal.
    if python3 - "${RESOLVED}" <<'PYEOF' >/dev/null 2>&1
import socket, sys
host = sys.argv[1]
for p in (443, 80):
    try:
        s = socket.create_connection((host, p), timeout=2)
        s.close()
        sys.exit(0)
    except Exception:
        continue
sys.exit(1)
PYEOF
    then
        PING_OK=1
    fi
fi

if [ "${PING_OK}" -eq 1 ]; then
    echo "Host ${HOST} is reachable."
    log "CONNECTIVITY OK: '${HOST}' is reachable"
else
    echo "Host ${HOST} is NOT reachable (or ICMP is blocked)."
    log "CONNECTIVITY FAILED: '${HOST}' is not reachable"
    STATUS=1
fi

# ---- Network interface information --------------------------------------------
echo
echo "=== Network Interfaces ==="
if command -v ip >/dev/null 2>&1; then
    ip -brief addr show 2>/dev/null || ip addr show
elif command -v ifconfig >/dev/null 2>&1; then
    ifconfig
elif [ -d /sys/class/net ]; then
    for iface in /sys/class/net/*; do
        name="$(basename "${iface}")"
        state="$(cat "${iface}/operstate" 2>/dev/null || echo unknown)"
        echo "${name}: state=${state}"
    done
else
    echo "No interface information available on this system."
fi
log "Displayed network interface information"

# ---- Optional TCP port check ---------------------------------------------------
if [ -n "${PORT}" ]; then
    echo
    echo "=== Port Check (TCP ${PORT}) ==="
    TARGET="${RESOLVED:-${HOST}}"
    PORT_OK=0

    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 3 "${HOST}" "${PORT}" >/dev/null 2>&1; then
            PORT_OK=1
        fi
    else
        if timeout 3 bash -c "exec 3<>/dev/tcp/${TARGET}/${PORT}" 2>/dev/null; then
            PORT_OK=1
        fi
    fi

    if [ "${PORT_OK}" -eq 1 ]; then
        echo "TCP port ${PORT} on ${HOST} is OPEN."
        log "PORT CHECK OK: ${HOST}:${PORT} is open"
    else
        echo "TCP port ${PORT} on ${HOST} is CLOSED or unreachable."
        log "PORT CHECK FAILED: ${HOST}:${PORT} is closed or unreachable"
        STATUS=1
    fi
fi

log "network-check.sh finished with status ${STATUS}"

exit "${STATUS}"
