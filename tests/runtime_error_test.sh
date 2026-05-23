#!/bin/sh
# Runtime-error reporting tests. Each case asserts that a runtime failure
# emits a diagnostic carrying the originating source line, and that the
# halt-vs-continue behaviour matches the failure's severity:
#
#   - Hard errors (Error)   halt   — code after the failing line must NOT run.
#   - Soft warnings (Warning) continue — code after the failing line MUST run.
#
# Detection uses two markers: every test prints MARKER-BEFORE then triggers
# the failure then prints MARKER-AFTER. Presence of MARKER-AFTER on stdout
# tells us whether execution halted.
#
# Usage: sh tests/runtime_error_test.sh [path-to-basic-binary]
#   default binary: ./basic (or ./basic.exe on Windows)
set -e

cd "$(dirname "$0")/.."

BASIC="${1:-./basic}"
if [ ! -x "$BASIC" ] && [ -x "${BASIC}.exe" ]; then
    BASIC="${BASIC}.exe"
fi
if [ ! -x "$BASIC" ]; then
    echo "runtime_error_test: binary not found or not executable: $BASIC" >&2
    exit 1
fi

DIR=tests/runtime_errors
fails=0

# run_stdout_case <file> <expected-stdout-substring>
# For builtins whose result lands on stdout (e.g. LASTERROR$()).
run_stdout_case() {
    file="$1"; want="$2"
    out=$("$BASIC" "$DIR/$file" 2>/dev/null) || true
    case "$out" in
        *"$want"*) echo "ok   $file (stdout): '$want'" ;;
        *) echo "FAIL $file: stdout missing '$want'"; echo "  got stdout: $out"; fails=$((fails + 1)) ;;
    esac
}

# run_case <file> <severity: halt|continue> <expected-stderr-substring>
run_case() {
    file="$1"; mode="$2"; want="$3"
    out=$("$BASIC" "$DIR/$file" 2>/tmp/rerr_stderr.$$) || true
    err=$(cat /tmp/rerr_stderr.$$ 2>/dev/null || true)
    rm -f /tmp/rerr_stderr.$$

    ok=1

    # 1. stderr must contain the expected diagnostic substring (which
    #    includes the source line, e.g. "Error on line 20").
    case "$err" in
        *"$want"*) : ;;
        *) echo "FAIL $file: stderr missing '$want'"; echo "  got stderr: $err"; ok=0 ;;
    esac

    # 2. halt/continue behaviour via MARKER-AFTER.
    case "$out" in
        *MARKER-AFTER*) seen_after=1 ;;
        *) seen_after=0 ;;
    esac
    if [ "$mode" = halt ] && [ "$seen_after" = 1 ]; then
        echo "FAIL $file: expected halt but MARKER-AFTER printed (kept running)"; ok=0
    fi
    if [ "$mode" = continue ] && [ "$seen_after" = 0 ]; then
        echo "FAIL $file: expected continue but MARKER-AFTER missing (halted)"; ok=0
    fi

    if [ "$ok" = 1 ]; then
        echo "ok   $file ($mode): '$want'"
    else
        fails=$((fails + 1))
    fi
}

# Hard errors — must report line and halt.
run_case mapload_error.bas halt    "Error on line 20"
run_case type_error.bas    halt    "Error on line 20"

# Soft warning — must report line and continue.
run_case open_warning.bas  continue "Warning on line 20"

# #INCLUDEd line — must report "at <file>:N" instead of "on line N" (Phase 2a).
run_case include_error.bas halt    "inc_lib.bas:110"

# #OPTION DIAGNOSTICS — HTTP soft-fail emits a non-halting Warning breadcrumb
# (Phase 2c). .invalid is RFC-6761 guaranteed to fail DNS, so status is 0.
run_case diagnostics_http.bas continue "HTTP\$ failed"

# LASTERROR$() — captures the last diagnostic text on stdout (Phase 2b).
run_stdout_case lasterror_capture.bas "CAPTURED:Warning on line 10"

if [ "$fails" -gt 0 ]; then
    echo "runtime_error_test: $fails case(s) failed" >&2
    exit 1
fi
echo "runtime_error_test: all cases passed"
