#!/usr/bin/env bash
# SCRIPT: test-chat-completions.sh
# DESCRIPTION: Send a chat completions request against the local Ollama API.
# USAGE: ./test-chat-completions.sh [-h]
# PARAMETERS:
# -h                : show help
# EXAMPLE: ./test-chat-completions.sh
# ----------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$PROJECT_ROOT/scripts/script-helpers}"
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

curl http://localhost:11434/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "deepseek-coder:1.3b",
        "messages": [
            {
                "role": "system",
                "content": "You are a helpful assistant."
            },
            {
                "role": "user",
                "content": "Write a Python script to calculate the factorial of a number."
            }
        ]
    }'
