#!/usr/bin/env bash
# SCRIPT: test-get-fallback-messages.sh
# DESCRIPTION: Verify fallback success messages when Ollama export is unavailable.
# USAGE: bash tests/test-get-fallback-messages.sh [-h]
# PARAMETERS:
# -h                : show help
# EXAMPLE: bash tests/test-get-fallback-messages.sh
# ----------------------------------------------------
set -euo pipefail

help() {
    cat <<'EOF'
Verify fallback success messaging for ./get when Ollama export is unavailable.

Usage:
  bash tests/test-get-fallback-messages.sh [-h]

Options:
  -h    Show help
EOF
}

while getopts ":h" opt; do
    case "${opt}" in
        h)
            help
            exit 0
            ;;
        \?)
            printf 'Invalid option: -%s\n\n' "$OPTARG" >&2
            help >&2
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=/dev/null
source "$PROJECT_ROOT/scripts/include.sh"

cd "$PROJECT_ROOT"

assert_contains() {
    local haystack=$1
    local needle=$2
    local label=$3

    if [[ "$haystack" != *"$needle"* ]]; then
        printf 'Assertion failed: %s\nExpected to find: %s\nIn: %s\n' "$label" "$needle" "$haystack" >&2
        exit 1
    fi
}

models_dir="${PROJECT_ROOT}/models"
docker_same="$(ollama_export_unavailable_message docker "./models/" "$models_dir")"
docker_diff="$(ollama_export_unavailable_message docker "./models/custom" "$models_dir")"
local_same="$(ollama_export_unavailable_message local "./models/" "$models_dir")"
local_diff="$(ollama_export_unavailable_message local "./models/custom" "$models_dir")"

assert_contains "$docker_same" "the runtime model store is ${models_dir}." "docker_same: runtime model store path"
assert_contains "$docker_diff" "no archive was written to ./models/custom." "docker_diff: no archive written message"
assert_contains "$docker_diff" "Docker runtime store at ${models_dir}." "docker_diff: Docker runtime store path"
assert_contains "$local_same" "the local runtime model store is ${models_dir}." "local_same: local runtime model store path"
assert_contains "$local_diff" "no archive was written to ./models/custom." "local_diff: no archive written message"
assert_contains "$local_diff" "local Ollama model store at ${models_dir}." "local_diff: local Ollama model store path"

ollama_model_menu_cache_path() { printf '%s\n' "$PROJECT_ROOT/.tmp-menu-cache.json"; }
ollama_model_menu_cache_is_fresh() { return 1; }
ollama_prepare_model_menu_cache() { return 1; }
show_model_catalog_loading_indicator() { :; }

if OLLAMA_MODEL_MENU_CACHE_MAX_ATTEMPTS=bogus OLLAMA_MODEL_MENU_CACHE_RETRY_DELAY_SECONDS=0 prepare_model_menu_cache_with_indicator "$PROJECT_ROOT/ollama-get-models/code/ollama_models.json"; then
    printf 'Expected invalid max attempts to fall back and return failure after retries.
' >&2
    exit 1
fi

if OLLAMA_MODEL_MENU_CACHE_MAX_ATTEMPTS=1 OLLAMA_MODEL_MENU_CACHE_RETRY_DELAY_SECONDS=bogus prepare_model_menu_cache_with_indicator "$PROJECT_ROOT/ollama-get-models/code/ollama_models.json"; then
    printf 'Expected invalid retry delay to fall back and still return failure after retries.
' >&2
    exit 1
fi

if OLLAMA_MODEL_MENU_CACHE_MAX_ATTEMPTS=1 OLLAMA_MODEL_MENU_CACHE_RETRY_DELAY_SECONDS=bogus require_model_menu_cache_file "$PROJECT_ROOT/ollama-get-models/code/ollama_models.json"; then
    printf 'Expected require_model_menu_cache_file to fail when cache prep fails.
' >&2
    exit 1
fi

ollama_prepare_model_menu_cache() { printf '%s
' "$PROJECT_ROOT/.tmp-menu-cache.json"; }
ollama_model_menu_cache_is_fresh() { [[ "$1" == "$PROJECT_ROOT/.tmp-menu-cache.json" ]]; }
cache_output_file="$PROJECT_ROOT/.tmp-cache-output.txt"
rm -f "$cache_output_file"
require_model_menu_cache_file "$PROJECT_ROOT/ollama-get-models/code/ollama_models.json" >"$cache_output_file"
cache_path="$(cat "$cache_output_file")"
rm -f "$cache_output_file"
assert_contains "$cache_path" "$PROJECT_ROOT/.tmp-menu-cache.json" "require_model_menu_cache_file returns cache path"
assert_contains "$OLLAMA_MODEL_MENU_CACHE_FILE" "$PROJECT_ROOT/.tmp-menu-cache.json" "require_model_menu_cache_file exports cache path"
