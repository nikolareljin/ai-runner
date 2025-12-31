#!/usr/bin/env bash
# SCRIPT: update.sh
# DESCRIPTION: Initialize and update git submodules.
# USAGE: ./scripts/update.sh [-h]
# PARAMETERS:
# -h                : show help
# EXAMPLE: ./scripts/update.sh
# ----------------------------------------------------
set -euo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SCRIPT_SOURCE" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    if [[ "$SCRIPT_SOURCE" != /* ]]; then
        SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
    fi
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$ROOT_DIR/scripts/script-helpers}"
HELPERS_PATH="$SCRIPT_HELPERS_DIR/helpers.sh"
if [[ -f "$HELPERS_PATH" ]]; then
    # shellcheck source=/dev/null
    source "$HELPERS_PATH"
    shlib_import logging help
else
    print_info() { printf "INFO: %s\n" "$1"; }
    print_success() { printf "OK: %s\n" "$1"; }
    print_error() { printf "ERROR: %s\n" "$1" >&2; }
    display_help() { printf "USAGE: %s [-h]\n" "$1"; }
fi

help() { display_help "$0"; }

while getopts ":h" opt; do
    case ${opt} in
        h) help; exit 0 ;;
        \?) print_error "Invalid option: -$OPTARG"; help; exit 1 ;;
    esac
done

print_info "Updating git submodules..."
git submodule update --init --recursive
print_success "Submodules updated."
