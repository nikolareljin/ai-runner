#!/usr/bin/env bash
# SCRIPT: include.sh
# DESCRIPTION: Legacy shim that loads script-helpers modules for ai-runner scripts.
# USAGE: source ./include.sh
# PARAMETERS:
# (none)
# EXAMPLE: source ./include.sh
# ----------------------------------------------------
set -euo pipefail

INCLUDE_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$INCLUDE_SOURCE" ]; do
    INCLUDE_DIR="$(cd "$(dirname "$INCLUDE_SOURCE")" && pwd)"
    INCLUDE_SOURCE="$(readlink "$INCLUDE_SOURCE")"
    if [[ "$INCLUDE_SOURCE" != /* ]]; then
        INCLUDE_SOURCE="$INCLUDE_DIR/$INCLUDE_SOURCE"
    fi
done
SCRIPT_DIR="$(cd "$(dirname "$INCLUDE_SOURCE")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$ROOT_DIR/scripts/script-helpers}"
HELPERS_PATH="$SCRIPT_HELPERS_DIR/helpers.sh"

print_info() { printf "INFO: %s\n" "$1"; }
print_success() { printf "OK: %s\n" "$1"; }
print_warning() { printf "WARN: %s\n" "$1"; }
print_error() { printf "ERROR: %s\n" "$1" >&2; }

prompt_install_script_helpers() {
    if [[ -f "$HELPERS_PATH" ]]; then
        return 0
    fi
    print_error "script-helpers dependency not found."
    print_info "Run ./update to initialize submodules."
    return 1
}

load_script_helpers() {
    if ! prompt_install_script_helpers; then
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$HELPERS_PATH"
    if [[ "$#" -gt 0 ]]; then
        shlib_import "$@"
    fi
}

load_script_helpers_if_available() {
    if ! prompt_install_script_helpers; then
        return 1
    fi
    # shellcheck source=/dev/null
    source "$HELPERS_PATH"
    if [[ "$#" -gt 0 ]]; then
        shlib_import "$@"
    fi
}

is_wsl() {
    grep -qi "microsoft" /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]
}
