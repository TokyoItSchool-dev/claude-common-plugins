#!/usr/bin/env bash
# Runs a test command, logs full output, prints a squeezed summary.
# Usage: run-tests.sh <test command...>
#        run-tests.sh --selftest

set -u

usage() {
    echo "usage: run-tests.sh <test command...>" >&2
    echo "       run-tests.sh --selftest" >&2
}

run_and_summarize() {
    log_dir="${RUN_TESTS_LOG_DIR:-${TMPDIR:-/tmp}}"
    log=""
    for d in "$log_dir" /tmp; do
        mkdir -p "$d" 2>/dev/null
        cand="$d/run-tests.$(date +%Y%m%d%H%M%S).$$.log"
        if printf '' 2>/dev/null >"$cand"; then
            log="$cand"
            break
        fi
    done

    if [ -z "$log" ]; then
        echo "run-tests.sh: warning: no writable log dir (tried '$log_dir' and /tmp), running without a log" >&2
        "$@"
        status=$?
        if [ "$status" -eq 0 ]; then
            echo "PASS | (no log captured, log dir unwritable) | log: none"
        else
            echo "FAIL (exit $status) | log: none (output was not captured, log dir unwritable)"
        fi
        return "$status"
    fi

    "$@" >"$log" 2>&1
    status=$?

    fail_lines="${RUN_TESTS_FAIL_LINES:-100}"
    case "$fail_lines" in
        ''|*[!0-9]*) fail_lines=100 ;;
    esac

    if [ "$status" -eq 0 ]; then
        last="$(grep -v '^[[:space:]]*$' "$log" | tail -n 1 | tr -d '\r')"
        printf '%s\n' "PASS | $last | log: $log" | cut -c1-200
    else
        echo "FAIL (exit $status) | log: $log"
        tail -n "$fail_lines" "$log"
        echo "... full log at $log (grep it for more)"
    fi

    return "$status"
}

selftest() {
    out1="$(run_and_summarize sh -c 'echo one; echo two; exit 0')"
    lc1=$(printf '%s\n' "$out1" | wc -l)
    [ "$lc1" -eq 1 ] || { echo "selftest FAIL: pass path printed $lc1 lines, want 1" >&2; exit 1; }

    out2="$(run_and_summarize sh -c 'echo boom; exit 3')"
    rc2=$?
    [ "$rc2" -eq 3 ] || { echo "selftest FAIL: exit code $rc2, want 3" >&2; exit 1; }
    lc2=$(printf '%s\n' "$out2" | wc -l)
    [ "$lc2" -gt 1 ] || { echo "selftest FAIL: fail path printed $lc2 lines, want >1" >&2; exit 1; }

    echo "selftest OK"
    exit 0
}

if [ "${1:-}" = "--selftest" ]; then
    selftest
fi

if [ "$#" -eq 0 ]; then
    usage
    exit 2
fi

run_and_summarize "$@"
exit $?
