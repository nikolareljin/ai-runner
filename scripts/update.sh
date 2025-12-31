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

print_info "Updating git submodules..."
git submodule update --init --recursive
print_success "Submodules updated."
