#!/usr/bin/env bash
# SCRIPT: prompt.sh
# DESCRIPTION: Prompt the configured Ollama model via the local API.
# USAGE: ./prompt.sh [-h] [-p "<prompt>"]
# PARAMETERS:
# -p "<prompt>"     : prompt to send (skips dialog)
# -h                : show help
# EXAMPLE: ./prompt.sh -p "What is the meaning of life?"
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
# shellcheck source=/dev/null
source "$SCRIPT_DIR/include.sh"
load_script_helpers logging dialog os env json file deps ollama help clipboard

ENV_FILE="$ROOT_DIR/.env"

cleanup_screen() {
    if [[ -t 1 ]]; then
        if command -v dialog >/dev/null 2>&1; then
            dialog --clear >/dev/null 2>&1 || true
        else
            clear >/dev/null 2>&1 || true
        fi
    fi
}
trap cleanup_screen EXIT

is_wsl() {
    grep -qi "microsoft" /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]
}

help() { display_help "$0"; }

copy_to_clipboard_safe() {
    local text="$1"
    if is_wsl && command -v clip.exe >/dev/null 2>&1; then
        printf "%s" "$text" | clip.exe
        print_info "Copied to Windows clipboard."
        return 0
    fi
    if ! copy_to_clipboard "$text"; then
        print_warning "Clipboard copy failed."
        return 1
    fi
}

prompt=""

while getopts ":hp:" opt; do
    case ${opt} in
        h) help; exit 0 ;;
        p) prompt="$OPTARG" ;;
        :) print_error "Option -$OPTARG requires an argument"; exit 1 ;;
        \?) print_error "Invalid option: -$OPTARG"; help; exit 1 ;;
    esac
done

if [[ -f "$ENV_FILE" ]]; then
    load_env "$ENV_FILE"
fi

model="$(resolve_env_value "model" "llama3" "$ENV_FILE")"
size="$(resolve_env_value "size" "latest" "$ENV_FILE")"

if [[ -z "$prompt" ]]; then
    dialog_init
    check_if_dialog_installed
    tmpin=$(mktemp)
    tmpout=$(mktemp)
    : > "$tmpin"
    if ! dialog --title "Enter your prompt" --editbox "$tmpin" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 2> "$tmpout"; then
        rm -f "$tmpin" "$tmpout"
        print_error "Prompt entry cancelled."
        exit 1
    fi
    prompt=$(cat "$tmpout")
    rm -f "$tmpin" "$tmpout"
    prompt=$(echo "$prompt" | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
fi

if [[ -z "$prompt" ]]; then
    print_error "No prompt provided. Exiting."
    exit 1
fi

model_ref="$(ollama_model_ref "$model" "$size")"
escaped_prompt=$(json_escape "$prompt")
payload="{\"model\":\"${model_ref}\",\"prompt\":\"${escaped_prompt}\",\"stream\":false}"
if ! curl -sS -X POST http://localhost:11434/api/generate -d "$payload" > "$ROOT_DIR/response.json"; then
    print_error "Failed to reach Ollama API at http://localhost:11434/api/generate"
    exit 1
fi

response_json=$(cat "$ROOT_DIR/response.json")
if ! response=$(format_response "$response_json"); then
    exit 1
fi
if [[ -z "$response" || "$response" == "null" ]]; then
    print_error "No response received."
    exit 1
fi

dialog_init
check_if_dialog_installed

dialog --title "Response" --msgbox "$response" "$DIALOG_HEIGHT" "$DIALOG_WIDTH"

copy_to_clipboard_safe "$response" || true
