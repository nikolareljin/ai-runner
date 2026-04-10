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

OLLAMA_MODEL_MENU_CACHE_TTL_SECONDS="${OLLAMA_MODEL_MENU_CACHE_TTL_SECONDS:-1800}"
OLLAMA_MODEL_MENU_CACHE_RETRY_DELAY_SECONDS="${OLLAMA_MODEL_MENU_CACHE_RETRY_DELAY_SECONDS:-1}"
OLLAMA_MODEL_MENU_CACHE_MAX_ATTEMPTS="${OLLAMA_MODEL_MENU_CACHE_MAX_ATTEMPTS:-5}"

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

has_interactive_dialog_session() {
    if [[ -t 2 || -t 1 || -t 0 ]]; then
        return 0
    fi

    if [[ -r /dev/tty && -w /dev/tty ]]; then
        return 0
    fi

    return 1
}

show_model_catalog_loading_indicator() {
    local default_message=$'Fetching Ollama model catalog...\nPreparing selection dialog.'
    local message="${1:-$default_message}"
    if ! has_interactive_dialog_session; then
        return 0
    fi
    dialog_init
    check_if_dialog_installed || return 0
    dialog_run --title "ai-runner" --infobox "$message" 8 60
    sleep 0.2
}

coerce_positive_integer() {
    local value="${1:-}"
    local fallback="${2:-1}"

    if [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
        printf '%s\n' "$value"
        return 0
    fi

    printf '%s\n' "$fallback"
}

coerce_nonnegative_sleep_delay() {
    local value="${1:-}"
    local fallback="${2:-1}"

    if [[ "$value" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]; then
        printf '%s\n' "$value"
        return 0
    fi

    printf '%s\n' "$fallback"
}

sleep_for_cache_retry_delay() {
    local delay="${1:-$OLLAMA_MODEL_MENU_CACHE_RETRY_DELAY_SECONDS}"

    delay="$(coerce_nonnegative_sleep_delay "$delay" "1")"
    sleep "$delay"
}

require_model_menu_cache_file() {
    local json_file="$1"
    local cache_file=""
    local status=0
    local effective_max_attempts=""
    local effective_ttl_seconds=""

    if cache_file="$(prepare_model_menu_cache_with_indicator "$json_file")"; then
        :
    else
        status=$?
        effective_max_attempts="$(coerce_positive_integer "${OLLAMA_MODEL_MENU_CACHE_MAX_ATTEMPTS:-}" "5")"
        effective_ttl_seconds="$(coerce_positive_integer "${OLLAMA_MODEL_MENU_CACHE_TTL_SECONDS:-}" "1800")"
        print_error "Failed to prepare model menu cache for JSON file: $json_file (attempts: $effective_max_attempts, TTL seconds: $effective_ttl_seconds)."
        return "$status"
    fi
    if [[ -z "$cache_file" ]]; then
        print_error "Model menu cache path is empty."
        return 1
    fi

    export OLLAMA_MODEL_MENU_CACHE_FILE="$cache_file"
    printf '%s\n' "$cache_file"
}

prepare_model_menu_cache_with_indicator() {
    local json_file="$1"
    local max_attempts="${2:-$OLLAMA_MODEL_MENU_CACHE_MAX_ATTEMPTS}"
    local ttl_seconds="$OLLAMA_MODEL_MENU_CACHE_TTL_SECONDS"
    local cache_path=""
    local attempt=1
    local last_status=1

    max_attempts="$(coerce_positive_integer "$max_attempts" "5")"
    ttl_seconds="$(coerce_positive_integer "$ttl_seconds" "1800")"

    cache_path="$(ollama_model_menu_cache_path "$json_file")" || return 1
    if ollama_model_menu_cache_is_fresh "$cache_path" "$ttl_seconds"; then
        printf '%s\n' "$cache_path"
        return 0
    fi

    while (( attempt <= max_attempts )); do
        local prepared_cache=""
        local loading_message=$'Fetching Ollama model catalog...\nBuilding model selection cache.'

        show_model_catalog_loading_indicator "$loading_message"
        if prepared_cache="$(ollama_prepare_model_menu_cache "$json_file" "$cache_path")"; then
            :
        else
            last_status=$?
            if (( attempt < max_attempts )); then
                sleep_for_cache_retry_delay "$OLLAMA_MODEL_MENU_CACHE_RETRY_DELAY_SECONDS"
            fi
            attempt=$((attempt + 1))
            continue
        fi
        if [[ -n "$prepared_cache" ]] && ollama_model_menu_cache_is_fresh "$prepared_cache" "$ttl_seconds"; then
            printf '%s\n' "$prepared_cache"
            return 0
        fi
        last_status=1
        if (( attempt < max_attempts )); then
            sleep_for_cache_retry_delay "$OLLAMA_MODEL_MENU_CACHE_RETRY_DELAY_SECONDS"
        fi
        attempt=$((attempt + 1))
    done

    return "$last_status"
}

normalize_compare_path() {
    local raw_path="$1"
    local normalized=""
    local abs_path=""
    local parent_dir=""
    local base_name=""
    local dir_norm=""
    local -a parts=()
    local -a resolved=("")
    local part=""

    if [[ -z "$raw_path" ]]; then
        printf '\n'
        return 0
    fi

    if command -v realpath >/dev/null 2>&1; then
        if normalized="$(realpath -m -- "$raw_path" 2>/dev/null)"; then
            printf '%s\n' "$normalized"
            return 0
        fi
    fi

    if command -v python3 >/dev/null 2>&1; then
        if normalized="$(python3 - "$raw_path" <<'PY2'
import os
import sys

print(os.path.normpath(os.path.abspath(sys.argv[1])))
PY2
        )"; then
            printf '%s\n' "$normalized"
            return 0
        fi
    fi

    if [[ -e "$raw_path" ]]; then
        if [[ -d "$raw_path" ]]; then
            if normalized="$(cd "$raw_path" 2>/dev/null && pwd -P)"; then
                printf '%s\n' "$normalized"
                return 0
            fi
        else
            parent_dir="$(dirname -- "$raw_path")"
            base_name="$(basename -- "$raw_path")"
            if dir_norm="$(cd "$parent_dir" 2>/dev/null && pwd -P)"; then
                printf '%s\n' "${dir_norm%/}/$base_name"
                return 0
            fi
        fi
    fi

    if [[ "$raw_path" == /* ]]; then
        abs_path="$raw_path"
    else
        abs_path="$PWD/${raw_path#./}"
    fi

    IFS='/' read -r -a parts <<< "$abs_path"
    for part in "${parts[@]}"; do
        if [[ -z "$part" || "$part" == "." ]]; then
            continue
        fi
        if [[ "$part" == ".." ]]; then
            if (( ${#resolved[@]} > 1 )); then
                unset 'resolved[${#resolved[@]}-1]'
            fi
            continue
        fi
        resolved+=("$part")
    done

    if (( ${#resolved[@]} == 1 )); then
        normalized="/"
    else
        local IFS='/'
        normalized="/${resolved[*]:1}"
    fi

    printf '%s\n' "$normalized"
}
paths_match_for_message() {
    local left="$1"
    local right="$2"
    local left_norm
    local right_norm

    left_norm="$(normalize_compare_path "$left")"
    right_norm="$(normalize_compare_path "$right")"

    [[ "$left_norm" == "$right_norm" ]]
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
