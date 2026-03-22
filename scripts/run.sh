#!/usr/bin/env bash
# SCRIPT: run.sh
# DESCRIPTION: Select an Ollama model/size, run it, and prompt the local API.
# USAGE: ./run.sh [-h] [-i] [-m <model>] [-p <prompt>] [-r <runtime>]
# PARAMETERS:
# -i                : install dependencies and Ollama CLI
# -m <model>        : preselect model for the dialog
# -p <prompt>       : prompt to send (skips prompt dialog)
# -r <runtime>      : runtime to use (local|docker)
# -h                : show help
# EXAMPLE: ./run.sh -i -m llama3 -p "Hello, how are you?" -r docker
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

help() { display_help "$0"; }

show_about_dialog() {
    dialog_init
    check_if_dialog_installed
    dialog --title "About ai-runner" --msgbox \
"ai-runner helps you select, run, and prompt local Ollama models from a dialog-based CLI.

Projects
AgentVault: https://github.com/nikolareljin/agentvault
burn-iso:   https://github.com/nikolareljin/burn-iso

Author profiles
GitHub: https://github.com/nikolareljin
LinkedIn: https://www.linkedin.com/in/nikolareljin" \
        "$DIALOG_HEIGHT" "$DIALOG_WIDTH" || true
    return 0
}

choose_start_action() {
    local choice=""
    local status=0

    while true; do
        dialog_init
        check_if_dialog_installed
        if choice=$(dialog --stdout --title "ai-runner" --menu "Choose an action" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 10 \
            "run" "Select a model and send a prompt" \
            "about" "About" \
            "quit" "Exit"); then
            :
        else
            status=$?
            if [[ $status -eq 1 || $status -eq 255 ]]; then
                return 2
            fi
            return "$status"
        fi

        case "$choice" in
            run)
                return 0
                ;;
            about)
                show_about_dialog
                ;;
            quit)
                return 2
                ;;
        esac
    done
}

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
runtime_override=""

while getopts ":him:p:r:" opt; do
    case ${opt} in
        h) help; exit 0 ;;
        i) run_install=true ;;
        m) model="$OPTARG" ;;
        p) prompt="$OPTARG" ;;
        r) runtime_override="$OPTARG" ;;
        :) print_error "Option -$OPTARG requires an argument"; exit 1 ;;
        \?) print_error "Invalid option: -$OPTARG"; help; exit 1 ;;
    esac
done

runtime_override="$(normalize_runtime_override "$runtime_override")"

if $run_install; then
    if [[ "${SKIP_SETUP_DEPS:-0}" == "1" ]]; then
        print_warning "SKIP_SETUP_DEPS=1 set; skipping setup-deps."
    elif [[ -x "$ROOT_DIR/setup-deps" ]]; then
        "$ROOT_DIR/setup-deps"
    elif [[ -x "$ROOT_DIR/scripts/setup-deps.sh" ]]; then
        "$ROOT_DIR/scripts/setup-deps.sh"
    else
        install_runner_dependencies
    fi
fi

if [[ -t 0 && -t 1 && -z "$model" && -z "$prompt" ]] && ! $run_install; then
    if choose_start_action; then
        show_model_catalog_loading_indicator
    else
        status=$?
        if [[ $status -eq 2 ]]; then
            print_info "Run cancelled."
            exit 0
        fi
        print_error "Failed to open start menu."
        exit "$status"
    fi
fi

if [[ ! -f "$ENV_FILE" ]]; then
    print_info "No .env file found. Creating from .env.example.txt"
    cp "$ROOT_DIR/.env.example.txt" "$ENV_FILE"
fi

load_env "$ENV_FILE"
runtime="$(ollama_runtime_type "$ENV_FILE" "$runtime_override")"
ollama_update_env "$ENV_FILE" ollama_runtime "$runtime"
ollama_runtime_sync_env_url "$ENV_FILE" >/dev/null
generate_endpoint="$(ollama_runtime_generate_endpoint "$ENV_FILE")"

json_file="$(ollama_models_json_path "$MODEL_REPO_DIR")"
if [[ ! -f "$json_file" ]]; then
    print_info "Model index not found. Preparing..."
    json_file="$(ollama_prepare_models_index "$MODEL_REPO_DIR")"
fi
if cache_file="$(require_model_menu_cache_file "$json_file")"; then
    :
else
    exit $?
fi

current_model="$(resolve_env_value "model" "$DEFAULT_MODEL" "$ENV_FILE")"
if [[ -n "$model" ]]; then
    current_model="$model"
fi

current_size="$(resolve_env_value "size" "latest" "$ENV_FILE")"
while true; do
    if ! selected_model="$(ollama_dialog_select_model "$json_file" "$current_model")"; then
        status=$?
        if [[ $status -eq 2 ]]; then
            print_info "Model selection cancelled."
            exit 0
        fi
        print_error "Failed to select model."
        exit "$status"
    fi
    if selected_size="$(ollama_dialog_select_size "$json_file" "$selected_model" "$current_size")"; then
        break
    fi
    status=$?
    if [[ $status -eq 2 ]]; then
        current_model="$selected_model"
        continue
    fi
    print_error "Failed to select model size."
    exit "$status"
done

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

if [[ "$runtime" == "docker" ]]; then
    ollama_runtime_ensure_ready "$runtime" "$ENV_FILE"
    ollama_runtime_pull_model "$runtime" "$ENV_FILE" "$selected_model" "$selected_size"
    print_info "Using Docker Ollama at $(ollama_runtime_api_base_url "$ENV_FILE")."
else
    if command -v ollama >/dev/null 2>&1; then
        ollama_runtime_pull_model "$runtime" "$ENV_FILE" "$selected_model" "$selected_size"
        ollama_runtime_run_model "$runtime" "$ENV_FILE" "$selected_model" "$selected_size"
    else
        if declare -F is_wsl >/dev/null 2>&1 && is_wsl; then
            print_warning "Ollama CLI not found in WSL. Ensure the Windows Ollama app is running with the model available."
        else
            print_warning "Ollama CLI not found. Skipping pull/run."
        fi
    fi
fi

model_ref="$(ollama_model_ref "$selected_model" "$selected_size")"
escaped_model_ref=$(json_escape "$model_ref")
escaped_prompt=$(json_escape "$prompt")
payload="{\"model\":\"${escaped_model_ref}\",\"prompt\":\"${escaped_prompt}\",\"stream\":false}"
if ! curl -sS -X POST "$generate_endpoint" -d "$payload" > "$ROOT_DIR/response.json"; then
    print_error "Failed to reach Ollama API at $generate_endpoint"
    exit 1
fi

response_json=$(cat "$ROOT_DIR/response.json")
if ! response=$(format_response "$response_json"); then
    print_error "Failed to format response from Ollama API. Raw response is saved at $ROOT_DIR/response.json"
    exit 1
fi
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
    echo "### Model: ${model_ref}"
    echo "### Size: ${selected_size}"
    echo "### Prompt: ${prompt}"
    echo "### Response:"
    echo "$formatted_md_response"
} > /tmp/response.md

# Do not let a missing/unavailable runtime make the script fail at the end.
ollama_runtime_ps "$runtime" "$ENV_FILE" || true
