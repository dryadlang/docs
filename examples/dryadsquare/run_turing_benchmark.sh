#!/usr/bin/env bash
# DryadSquare Turing-completeness benchmark gate.
# Usage: ./examples/dryadsquare/run_turing_benchmark.sh [--verbose]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The docs module is checked out at <source>/docs. Fall back to the old
# <source>/examples layout when the source tree is self-contained.
if [[ -f "$SCRIPT_DIR/../../../src/CMakeLists.txt" ]]; then
    ROOT_DIR="$(cd "$SCRIPT_DIR/../../../src" && pwd)"
elif [[ -f "$SCRIPT_DIR/../../CMakeLists.txt" ]]; then
    ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
else
    ROOT_DIR=""
fi

if [[ -n "$ROOT_DIR" ]]; then
    BINARY="${DRYAD_BIN:-$ROOT_DIR/build/bin/dryad}"
    STDLIB="${DRYAD_STDLIB_DIR:-$ROOT_DIR/stdlib}"
else
    BINARY="${DRYAD_BIN:-}"
    STDLIB="${DRYAD_STDLIB_DIR:-}"
fi
TARGET="$SCRIPT_DIR/dryadsquare.dryad"
RUN_TIMEOUT="${DRYAD_RUN_TIMEOUT:-60}"
COMPILE_TIMEOUT="${DRYAD_COMPILE_TIMEOUT:-120}"
VERBOSE=0

for arg in "$@"; do
    case "$arg" in
        --verbose|-v) VERBOSE=1 ;;
        --help|-h)
            echo "Usage: $0 [--verbose]"
            exit 0
            ;;
    esac
done

if [[ -z "$BINARY" || ! -x "$BINARY" ]]; then
    echo "ERROR: dryad binary not found${BINARY:+ at $BINARY}."
    echo "Set DRYAD_BIN, or check out this module at <source>/docs and build the source first."
    exit 1
fi

if [[ -n "$STDLIB" ]]; then
    export DRYAD_STDLIB_DIR="$STDLIB"
fi

PASS=0
FAIL=0

run_mode() {
    local mode="$1"
    local flags="$2"
    local out
    if [[ "$mode" == "aot" ]]; then
        local ll_out="/tmp/dryadsquare_benchmark.ll"
        if timeout "$COMPILE_TIMEOUT" "$BINARY" compile "$TARGET" --aot -o "$ll_out" >/dev/null 2>&1; then
            rm -f "$ll_out"
            return 0
        fi
        return 1
    fi

    local cmd=("$BINARY")
    if [[ -n "$flags" ]]; then
        # shellcheck disable=SC2206
        cmd+=($flags)
    fi
    cmd+=("$TARGET")

    if out="$(timeout "$RUN_TIMEOUT" "${cmd[@]}" 2>&1)"; then
        if [[ $VERBOSE -eq 1 ]]; then
            echo "$out"
        fi
        if echo "$out" | grep -q "TURING_BENCHMARK_OK"; then
            return 0
        fi
        echo "Missing TURING_BENCHMARK_OK in $mode output"
        [[ $VERBOSE -eq 1 ]] || echo "$out"
        return 1
    fi
    return 1
}

printf "\n%-12s %8s\n" "MODE" "STATUS"
printf "%-12s %8s\n" "------------" "--------"

if run_mode "interp" ""; then
    printf "%-12s %8s\n" "interpreter" "PASS"
    PASS=$((PASS + 1))
else
    printf "%-12s %8s\n" "interpreter" "FAIL"
    FAIL=$((FAIL + 1))
fi

if run_mode "vm" "--vm"; then
    printf "%-12s %8s\n" "vm" "PASS"
    PASS=$((PASS + 1))
else
    printf "%-12s %8s\n" "vm" "FAIL"
    FAIL=$((FAIL + 1))
fi

if run_mode "aot" ""; then
    printf "%-12s %8s\n" "aot" "PASS"
    PASS=$((PASS + 1))
else
    printf "%-12s %8s\n" "aot" "FAIL"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "DryadSquare benchmark: $PASS/3 modes passed"

if [[ $FAIL -eq 0 ]]; then
    echo "TURING_BENCHMARK_GATE_OK"
    exit 0
fi

exit 1
