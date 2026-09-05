#!/usr/bin/env bash
#
# grade.sh — Assignment 1 grader
#
# Checks: required files, Bash syntax, executable permissions,
# system-info.sh output, disk-check.sh argument validation,
# network-check.sh validation, logging, and basic Git history.
#
# Usage: ./grade.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}" || exit 1

PASS=0
FAIL=0
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

pass() {
    echo "  [PASS] $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "  [FAIL] $1"
    FAIL=$((FAIL + 1))
}

section() {
    echo
    echo "== $1 =="
}

# ------------------------------------------------------------------
section "Required files"
# ------------------------------------------------------------------
REQUIRED_FILES=(README.md system-info.sh disk-check.sh network-check.sh grade.sh logs/.gitkeep)
for f in "${REQUIRED_FILES[@]}"; do
    if [ -e "${f}" ]; then
        pass "Found ${f}"
    else
        fail "Missing ${f}"
    fi
done

# ------------------------------------------------------------------
section "Bash syntax"
# ------------------------------------------------------------------
for f in system-info.sh disk-check.sh network-check.sh; do
    if [ -f "${f}" ]; then
        if bash -n "${f}" 2>"${TMP_DIR}/syntax-${f//\//_}.err"; then
            pass "${f} has valid Bash syntax"
        else
            fail "${f} has syntax errors: $(cat "${TMP_DIR}/syntax-${f//\//_}.err")"
        fi
    else
        fail "${f} not found; cannot check syntax"
    fi
done

# ------------------------------------------------------------------
section "Executable permissions"
# ------------------------------------------------------------------
for f in system-info.sh disk-check.sh network-check.sh grade.sh; do
    if [ -f "${f}" ]; then
        if [ -x "${f}" ]; then
            pass "${f} is executable"
        else
            fail "${f} is not executable (chmod +x ${f})"
        fi
    else
        fail "${f} not found; cannot check permissions"
    fi
done

# ------------------------------------------------------------------
section "system-info.sh output"
# ------------------------------------------------------------------
if [ -x system-info.sh ]; then
    OUTPUT="$(./system-info.sh 2>"${TMP_DIR}/system-info.err")"
    EXIT_CODE=$?
    if [ "${EXIT_CODE}" -eq 0 ]; then
        pass "system-info.sh exited successfully"
    else
        fail "system-info.sh exited with code ${EXIT_CODE}"
    fi

    declare -A EXPECTED_SECTIONS=(
        [Hostname]="hostname"
        ["Current User"]="current user"
        ["Date / Time"]="date/time"
        ["Operating System"]="operating system"
        ["Kernel Version"]="kernel version"
        [Uptime]="uptime"
        ["CPU Information"]="CPU information"
        ["Memory Information"]="memory information"
        ["Current Working Directory"]="current working directory"
    )
    for key in "${!EXPECTED_SECTIONS[@]}"; do
        if echo "${OUTPUT}" | grep -qi "${key}"; then
            pass "Output includes ${EXPECTED_SECTIONS[$key]}"
        else
            fail "Output missing ${EXPECTED_SECTIONS[$key]} section (expected header like '${key}')"
        fi
    done

    LIVE_HOSTNAME="$(hostname)"
    if echo "${OUTPUT}" | grep -qF "${LIVE_HOSTNAME}"; then
        pass "Reported hostname matches the live system (${LIVE_HOSTNAME})"
    else
        fail "Reported hostname does not match live system hostname (${LIVE_HOSTNAME})"
    fi

    LIVE_USER="$(whoami)"
    if echo "${OUTPUT}" | grep -qF "${LIVE_USER}"; then
        pass "Reported user matches the live system (${LIVE_USER})"
    else
        fail "Reported user does not match live system user (${LIVE_USER})"
    fi

    LIVE_PWD="$(pwd)"
    if echo "${OUTPUT}" | grep -qF "${LIVE_PWD}"; then
        pass "Reported working directory matches live pwd (${LIVE_PWD})"
    else
        fail "Reported working directory does not match live pwd (${LIVE_PWD})"
    fi
else
    fail "system-info.sh is not executable; skipped output checks"
fi

# ------------------------------------------------------------------
section "disk-check.sh argument validation"
# ------------------------------------------------------------------
if [ -x disk-check.sh ]; then
    ./disk-check.sh 99 / >/dev/null 2>&1
    [ $? -eq 0 ] && pass "Exits 0 for a high threshold (usage below threshold)" \
                 || fail "Did not exit 0 for a high threshold"

    ./disk-check.sh 1 / >/dev/null 2>&1
    RC=$?
    [ "${RC}" -ne 0 ] && [ "${RC}" -ne 2 ] && pass "Exits non-zero (non-2) when usage reaches/exceeds a low threshold" \
                 || fail "Did not exit correctly for a threshold usage should exceed (got ${RC})"

    ./disk-check.sh abc / >/dev/null 2>&1
    [ $? -eq 2 ] && pass "Exits 2 for a non-integer threshold" \
                 || fail "Did not exit 2 for a non-integer threshold"

    ./disk-check.sh 0 / >/dev/null 2>&1
    [ $? -eq 2 ] && pass "Exits 2 for an out-of-range threshold (0)" \
                 || fail "Did not exit 2 for threshold 0"

    ./disk-check.sh 101 / >/dev/null 2>&1
    [ $? -eq 2 ] && pass "Exits 2 for an out-of-range threshold (101)" \
                 || fail "Did not exit 2 for threshold 101"

    ./disk-check.sh >/dev/null 2>&1
    [ $? -eq 2 ] && pass "Exits 2 when no arguments are supplied" \
                 || fail "Did not exit 2 for missing arguments"

    ./disk-check.sh 50 /definitely/not/a/real/path >/dev/null 2>&1
    [ $? -eq 2 ] && pass "Exits 2 for an invalid path" \
                 || fail "Did not exit 2 for an invalid path"

    OUT="$(./disk-check.sh 99 / 2>/dev/null)"
    if echo "${OUT}" | grep -qE '[0-9]+%'; then
        pass "Displays a disk usage percentage"
    else
        fail "Did not display a disk usage percentage"
    fi
else
    fail "disk-check.sh is not executable; skipped validation checks"
fi


# ------------------------------------------------------------------
section "network-check.sh validation"
# ------------------------------------------------------------------
if [ -x network-check.sh ]; then
    ./network-check.sh >/dev/null 2>&1
    [ $? -eq 2 ] && pass "Exits 2 when no host is supplied" \
                 || fail "Did not exit 2 for missing host"

    ./network-check.sh "invalid host with spaces" >/dev/null 2>&1
    [ $? -eq 2 ] && pass "Exits 2 for an invalid host string" \
                 || fail "Did not exit 2 for an invalid host string"

    ./network-check.sh 127.0.0.1 0 >/dev/null 2>&1
    [ $? -eq 2 ] && pass "Exits 2 for an out-of-range port (0)" \
                 || fail "Did not exit 2 for port 0"

    ./network-check.sh 127.0.0.1 70000 >/dev/null 2>&1
    [ $? -eq 2 ] && pass "Exits 2 for an out-of-range port (70000)" \
                 || fail "Did not exit 2 for port 70000"

    ./network-check.sh 127.0.0.1 abc >/dev/null 2>&1
    [ $? -eq 2 ] && pass "Exits 2 for a non-numeric port" \
                 || fail "Did not exit 2 for a non-numeric port"

    OUT="$(./network-check.sh 127.0.0.1 2>/dev/null)"
    RC=$?
    if [ "${RC}" -eq 0 ] || [ "${RC}" -eq 1 ]; then
        pass "Runs to completion without crashing on a valid host (exit ${RC})"
    else
        fail "Did not exit with 0 or 1 for a valid host (got ${RC})"
    fi

    if echo "${OUT}" | grep -qi "resolv"; then
        pass "Displays resolved address information"
    else
        fail "Did not display resolved address information"
    fi

    if echo "${OUT}" | grep -qiE "interface|eth0|lo:"; then
        pass "Displays network interface information"
    else
        fail "Did not display network interface information"
    fi
else
    fail "network-check.sh is not executable; skipped validation checks"
fi

# ------------------------------------------------------------------
section "Logging"
# ------------------------------------------------------------------
if [ -d logs ]; then
    pass "logs/ directory exists"
    LOG_COUNT="$(find logs -maxdepth 1 -name '*.log' 2>/dev/null | wc -l)"
    if [ "${LOG_COUNT}" -gt 0 ]; then
        pass "Found ${LOG_COUNT} log file(s) under logs/"
        TIMESTAMPED=0
        for lf in logs/*.log; do
            [ -f "${lf}" ] || continue
            if grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "${lf}"; then
                TIMESTAMPED=1
            fi
        done
        if [ "${TIMESTAMPED}" -eq 1 ]; then
            pass "Log entries contain timestamps"
        else
            fail "Log entries do not appear to contain timestamps"
        fi
    else
        fail "No log files found under logs/ (run the scripts at least once)"
    fi
else
    fail "logs/ directory does not exist"
fi

# ------------------------------------------------------------------
section "Git history"
# ------------------------------------------------------------------
if [ -d .git ]; then
    pass "Git repository found"

    COMMIT_COUNT="$(git log --oneline 2>/dev/null | wc -l)"
    if [ "${COMMIT_COUNT}" -ge 5 ]; then
        pass "At least 5 commits found (${COMMIT_COUNT})"
    else
        fail "Fewer than 5 commits found (${COMMIT_COUNT})"
    fi

    BRANCH_COUNT="$(git branch --list 2>/dev/null | grep -vc -E '^\*? *(main|master)$')"
    if [ "${BRANCH_COUNT}" -ge 1 ]; then
        pass "At least one non-main/master branch exists (or existed)"
    else
        # Branch may have already been deleted after merge; check merge commits instead.
        if git log --merges --oneline 2>/dev/null | grep -q .; then
            pass "Merge commit found, indicating a feature branch was used"
        else
            fail "No non-main/master branch or merge commit found"
        fi
    fi

    if git log --merges --oneline 2>/dev/null | grep -q .; then
        pass "Feature branch merge commit found in history"
    else
        fail "No merge commit found (feature branch was not merged)"
    fi

    if git log --oneline 2>/dev/null | grep -qE '^[a-f0-9]+ .{10,}'; then
        pass "Commit messages appear descriptive"
    else
        fail "Commit messages appear too short or missing"
    fi
else
    fail "No Git repository found (.git directory missing)"
fi

# ------------------------------------------------------------------
section "Summary"
# ------------------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo "Passed: ${PASS} / ${TOTAL}"

if [ "${FAIL}" -eq 0 ]; then
    echo "Result: ALL CHECKS PASSED"
    exit 0
else
    echo "Result: ${FAIL} CHECK(S) FAILED"
    exit 1
fi
