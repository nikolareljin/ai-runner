#!/usr/bin/env bash
# SCRIPT: update.sh
# DESCRIPTION: Initialize and update the script-helpers git submodule.
# USAGE: ./scripts/update.sh [-h] [-r]
# PARAMETERS:
# -h                : show help
# -r                : update submodule to latest remote commit on configured branch
# EXAMPLE: ./scripts/update.sh
# ----------------------------------------------------
set -euo pipefail

SUBMODULE_PATH="scripts/script-helpers"

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SCRIPT_SOURCE" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    if [[ "$SCRIPT_SOURCE" != /* ]]; then
        SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
    fi
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/include.sh"
load_script_helpers_if_available logging help || true

help() { display_help "$0"; }

update_remote=false
while getopts ":hr" opt; do
    case ${opt} in
        h) help; exit 0 ;;
        r) update_remote=true ;;
        \?) print_error "Invalid option: -$OPTARG"; help; exit 1 ;;
    esac
done

print_info "Updating script-helpers submodule..."
git submodule sync --recursive -- "$SUBMODULE_PATH"
if $update_remote; then
    git submodule update --init --recursive --remote "$SUBMODULE_PATH"
else
    git submodule update --init --recursive -- "$SUBMODULE_PATH"
fi
print_success "script-helpers submodule updated."
