#!/usr/bin/env bash
# SCRIPT: example.sh
# DESCRIPTION: Bootstrap the Next.js demo with the Vercel AI Ollama example.
# USAGE: ./example.sh [-h]
# PARAMETERS:
# -h                : show help
# EXAMPLE: ./example.sh
# ----------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$SCRIPT_DIR/scripts/script-helpers}"
# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging deps help env

help() { display_help "$0"; }

ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"
ENV_EXAMPLE_TXT="$SCRIPT_DIR/.env.example.txt"

ensure_env_file() {
    if [[ ! -f "$ENV_EXAMPLE" && -f "$ENV_EXAMPLE_TXT" ]]; then
        cp "$ENV_EXAMPLE_TXT" "$ENV_EXAMPLE"
    fi
    if [[ ! -f "$ENV_FILE" && -f "$ENV_EXAMPLE" ]]; then
        cp "$ENV_EXAMPLE" "$ENV_FILE"
    fi
}

write_example_env() {
    local model size website base_url model_full
    load_env "$ENV_FILE"
    model="$(resolve_env_value "model" "llama3" "$ENV_FILE")"
    size="$(resolve_env_value "size" "" "$ENV_FILE")"
    website="$(resolve_env_value "website" "http://localhost:11434/api/generate" "$ENV_FILE")"
    base_url="${website%/api/generate}"
    if [[ "$base_url" == "$website" ]]; then
        base_url="${website%/api/*}"
    fi
    if [[ -z "$base_url" ]]; then
        base_url="$website"
    fi
    model_full="$model"
    if [[ -n "$size" && "$model" != *:* ]]; then
        model_full="${model}:${size}"
    fi
    cat > "$SCRIPT_DIR/example/.env.local" <<EOF
OLLAMA_BASE_URL=${base_url}
OLLAMA_MODEL=${model_full}
EOF
}

while getopts ":h" opt; do
    case ${opt} in
        h) help; exit 0 ;;
        \?) print_error "Invalid option: -$OPTARG"; help; exit 1 ;;
    esac
done

install_dependencies_ai_runner

ensure_env_file
npx create-next-app --example https://github.com/vercel/ai/tree/main/examples/next-ollama example
cd example
npm install @vercel/ai

write_example_env
print_info "Configured example/.env.local from .env (model/size/website)."
print_info "Next: add your API route under app/api/chat/route.ts if you want to customize it further."
