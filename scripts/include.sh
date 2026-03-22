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

normalize_runtime_override() {
    local value="${1:-}"
    printf '%s' "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]'
}

show_model_catalog_loading_indicator() {
    local message="${1:-Fetching Ollama model catalog...
Preparing selection dialog.}"
    if [[ ! -t 0 || ! -t 1 ]]; then
        return 0
    fi
    dialog_init
    check_if_dialog_installed || return 0
    dialog --title "ai-runner" --infobox "$message" 8 60
    sleep 0.2
}

prepare_model_menu_cache_with_indicator() {
    local json_file="$1"
    local max_attempts="${2:-5}"
    local cache_file=""
    local attempt=1

    cache_file="$(ollama_model_menu_cache_path "$json_file")" || return 1
    if ollama_model_menu_cache_is_fresh "$cache_file" 1800; then
        printf '%s\n' "$cache_file"
        return 0
    fi

    while (( attempt <= max_attempts )); do
        show_model_catalog_loading_indicator "Fetching Ollama model catalog...
Building model selection cache."
        cache_file="$(ollama_prepare_model_menu_cache "$json_file" "$cache_file")" || return 1
        if [[ -n "$cache_file" ]] && ollama_model_menu_cache_is_fresh "$cache_file" 1800; then
            printf '%s\n' "$cache_file"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 0.2
    done

    print_error "Failed to prepare a fresh model selection cache after ${max_attempts} attempts."
    return 1
}

normalize_compare_path() {
    local raw_path="$1"
    local normalized=""

    if [[ -z "$raw_path" ]]; then
        printf "\n"
        return 0
    fi

    if command -v realpath >/dev/null 2>&1; then
        if normalized="$(realpath -m -- "$raw_path" 2>/dev/null)"; then
            printf "%s\n" "$normalized"
            return 0
        fi
    fi

    if command -v python3 >/dev/null 2>&1; then
        if normalized="$(python3 - "$raw_path" <<'PY'
import os
import sys

print(os.path.normpath(os.path.abspath(sys.argv[1])))
PY
        )"; then
            printf "%s\n" "$normalized"
            return 0
        fi
    fi

    normalized="${raw_path%/}"
    [[ -z "$normalized" ]] && normalized="/"
    printf "%s\n" "$normalized"
}

paths_match_for_message() {
    local left="$1"
    local right="$2"
    [[ "$(normalize_compare_path "$left")" == "$(normalize_compare_path "$right")" ]]
}

ollama_export_unavailable_message() {
    local runtime="$1"
    local requested_dir="$2"
    local cache_dir="$3"

    if [[ "$runtime" == "docker" ]]; then
        if paths_match_for_message "$requested_dir" "$cache_dir"; then
            printf "%s\n" "Model pulled successfully. This Ollama build does not support 'ollama export'; the runtime model store is ${cache_dir}."
        else
            printf "%s\n" "Model pulled successfully. This Ollama build does not support 'ollama export'; no archive was written to ${requested_dir}. The model is available through the Docker runtime store at ${cache_dir}."
        fi
        return 0
    fi

    if paths_match_for_message "$requested_dir" "$cache_dir"; then
        printf "%s\n" "Model pulled successfully. This Ollama build does not support 'ollama export'; the local runtime model store is ${cache_dir}."
    else
        printf "%s\n" "Model pulled successfully. This Ollama build does not support 'ollama export'; no archive was written to ${requested_dir}. The model is available through the local Ollama model store at ${cache_dir}."
    fi
}
