#!/usr/bin/env bash
# SCRIPT: run.sh
# DESCRIPTION: Select an Ollama model/size, run it, and prompt the local API.
# USAGE: ./run.sh [-h] [-i] [-m <model>] [-p <prompt>]
# PARAMETERS:
# -i                : install dependencies and Ollama CLI
# -m <model>        : preselect model for the dialog
# -p <prompt>       : prompt to send (skips prompt dialog)
# -h                : show help
# EXAMPLE: ./run.sh -i -m llama3 -p "Hello, how are you?"
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

DEFAULT_MODEL="llama3"
ENV_FILE="$ROOT_DIR/.env"
MODEL_REPO_DIR="$ROOT_DIR/ollama-get-models"

is_wsl() {
    grep -qi "microsoft" /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]
}

help() { display_help "$0"; }

install_runner_dependencies() {
    if is_wsl; then
        print_info "WSL2 detected: installing common dependencies; Ollama CLI is expected on Windows host."
        install_dependencies dialog curl jq python3 python3-pip nodejs git
        if command -v clip.exe >/dev/null 2>&1; then
            print_info "WSL2: clipboard will use clip.exe."
        else
            print_warning "WSL2: clip.exe not found; clipboard copy may fail."
        fi
    else
        install_dependencies_ai_runner
    fi
}

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

run_install=false
model=""
prompt=""

while getopts ":him:p:" opt; do
    case ${opt} in
        h) help; exit 0 ;;
        i) run_install=true ;;
        m) model="$OPTARG" ;;
        p) prompt="$OPTARG" ;;
        :) print_error "Option -$OPTARG requires an argument"; exit 1 ;;
        \?) print_error "Invalid option: -$OPTARG"; help; exit 1 ;;
    esac
done

if $run_install; then
    install_runner_dependencies
fi

if [[ ! -f "$ENV_FILE" ]]; then
    print_info "No .env file found. Creating from .env.example.txt"
    cp "$ROOT_DIR/.env.example.txt" "$ENV_FILE"
fi

load_env "$ENV_FILE"

json_file="$(ollama_models_json_path "$MODEL_REPO_DIR")"
if [[ ! -f "$json_file" ]]; then
    print_info "Model index not found. Preparing..."
    json_file="$(ollama_prepare_models_index "$MODEL_REPO_DIR")"
fi

current_model="$(resolve_env_value "model" "$DEFAULT_MODEL" "$ENV_FILE")"
if [[ -n "$model" ]]; then
    current_model="$model"
fi

selected_model="$(ollama_dialog_select_model "$json_file" "$current_model")"
current_size="$(resolve_env_value "size" "latest" "$ENV_FILE")"
selected_size="$(ollama_dialog_select_size "$json_file" "$selected_model" "$current_size")"

ollama_update_env "$ENV_FILE" model "$selected_model"
ollama_update_env "$ENV_FILE" size "$selected_size"

if [[ -z "$prompt" ]]; then
    dialog_init
    check_if_dialog_installed
    tmpin=$(mktemp)
    tmpout=$(mktemp)
    : > "$tmpin"
    if ! dialog --title "Enter a prompt" --editbox "$tmpin" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 2> "$tmpout"; then
        rm -f "$tmpin" "$tmpout"
        print_error "Prompt entry cancelled."
        exit 1
    fi
    prompt=$(cat "$tmpout")
    rm -f "$tmpin" "$tmpout"
    prompt=$(echo "$prompt" | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
fi

if [[ -z "$prompt" ]]; then
    print_error "No prompt entered. Exiting."
    exit 1
fi

if command -v ollama >/dev/null 2>&1; then
    ollama_pull_model "$selected_model" "$selected_size"
    ollama_run_model "$selected_model" "$selected_size"
else
    if is_wsl; then
        print_warning "Ollama CLI not found in WSL. Ensure the Windows Ollama app is running with the model available."
    else
        print_warning "Ollama CLI not found. Skipping pull/run."
    fi
fi

escaped_prompt=$(json_escape "$prompt")
payload="{\"model\":\"${selected_model}\",\"prompt\":\"${escaped_prompt}\",\"stream\":false}"
if ! curl -sS -X POST http://localhost:11434/api/generate -d "$payload" > "$ROOT_DIR/response.json"; then
    print_error "Failed to reach Ollama API at http://localhost:11434/api/generate"
    exit 1
fi

response_json=$(cat "$ROOT_DIR/response.json")
response=$(format_response "$response_json")
if [[ -z "$response" || "$response" == "null" ]]; then
    print_error "No response received."
    exit 1
fi

copy_to_clipboard_safe "$response" || true

dialog_init
check_if_dialog_installed

dialog --title "Response" --msgbox "$response" "$DIALOG_HEIGHT" "$DIALOG_WIDTH"

formatted_md_response=$(format_md_response "$response")
{
    echo "## Response"
    echo "### Model: ${selected_model}"
    echo "### Size: ${selected_size}"
    echo "### Prompt: ${prompt}"
    echo "### Response:"
    echo "$formatted_md_response"
} > /tmp/response.md

if command -v ollama >/dev/null 2>&1; then
    ollama ps
fi
