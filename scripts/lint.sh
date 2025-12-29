#!/usr/bin/env bash
# SCRIPT: lint.sh
# DESCRIPTION: Run ShellCheck on tracked shell scripts.
# USAGE: ./scripts/lint.sh [-h]
# PARAMETERS:
# -h                : show help
# EXAMPLE: ./scripts/lint.sh
# ----------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$SCRIPT_DIR/script-helpers}"
# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging help

help() { display_help "$0"; }

while getopts ":h" opt; do
    case ${opt} in
        h) help; exit 0 ;;
        \?) print_error "Invalid option: -$OPTARG"; help; exit 1 ;;
    esac
done

if ! command -v shellcheck >/dev/null 2>&1; then
    print_error "ShellCheck not found. Install with:"
    echo "  - macOS:   brew install shellcheck"
    echo "  - Ubuntu:  sudo apt-get update && sudo apt-get install -y shellcheck"
    exit 1
fi

readarray -t FILES < <(git ls-files '*.sh')

if [ "${#FILES[@]}" -eq 0 ]; then
    print_info "No shell scripts found."
    exit 0
fi

print_info "Running ShellCheck on:"
for f in "${FILES[@]}"; do
    echo " - $f"
done

STRICT=${STRICT:-0}

if [ "${STRICT}" = "1" ]; then
    shellcheck -S style -x -e SC1091 "${FILES[@]}"
else
    shellcheck -S style -x -e SC1091 "${FILES[@]}" || true
    print_info "Warnings are not failing the build; run with STRICT=1 to enforce."
fi
