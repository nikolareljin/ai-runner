#!/usr/bin/env bash
# SCRIPT: include.sh
# DESCRIPTION: Legacy shim that loads script-helpers modules for ai-runner scripts.
# USAGE: source ./include.sh
# PARAMETERS:
# (none)
# EXAMPLE: source ./include.sh
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
shlib_import logging dialog os env json file deps ollama help clipboard

is_wsl() {
    grep -qi "microsoft" /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]
}
