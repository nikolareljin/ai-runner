#!/bin/bash
# SCRIPT: get.sh
# DESCRIPTION: Download a model archive for offline reuse.
# USAGE: ./get.sh [-m <model>] [-u <url>] [-d <dir>]
# PARAMETERS:
# -m <model>        : model name (default: llama3)
# -u <url>          : model url (if not in the list)
# -d <dir>          : directory to download the model to (default: current directory)
# EXAMPLE: ./get.sh -m llama3 -d /path/to/download
# ----------------------------------------------------
# This script downloads a model from the Ollama website.
# It uses curl to download the model and tar to extract it.

source ./include.sh
if [ -f ./.env ]; then
  # shellcheck disable=SC1091
  source ./.env
fi

# Download the model to a designated location.
# Uses dialog to select where to download, and a progress bar to show the download progress.

# Default values
model=""
size=""
url=""
dir=""

help() {
    display_help
    exit 1
}

# Parse the arguments
while getopts "hm:u:d:" opt; do
    case ${opt} in
        h)
            help
            ;;
        m )
            model=$OPTARG
            ;;
        u )
            url=$OPTARG
            ;;
        d )
            dir=$OPTARG
            ;;
        \? )
            echo "Usage: cmd [-m <model>] [-u <url>] [-d <dir>]"
            exit 1
            ;;
    esac
done

MODEL_FILE="./ollama-get-models/code/ollama_models.json"

# If neither model nor URL provided, open interactive selector (like run.sh)
if [[ -z "$model" && -z "$url" ]]; then
    if [ ! -f "$MODEL_FILE" ]; then
        print_info "Model index not found. Installing dependencies and building index..."
        install_dependencies
        if [ ! -f "$MODEL_FILE" ]; then
            print_error "Model index still missing after install. Aborting."
            exit 1
        fi
    fi

    # Sort JSON and build options list
    jq -S 'sort_by(.name)' "$MODEL_FILE" > "${MODEL_FILE}.tmp" && mv "${MODEL_FILE}.tmp" "$MODEL_FILE"
    options=$(jq -r '.[] | "\(.name) sizes:\t\(.sizes)"' "$MODEL_FILE")
    menu_items=()

    # Preselect current env model if present
    current_model="${model:-}"
    if [[ -z "$current_model" && -f ./.env ]]; then
        current_model=$(grep -oP '^model=\K.*' ./.env 2>/dev/null || true)
    fi

    while IFS= read -r line; do
        key=$(echo "$line" | awk '{print $1}')
        value=$(echo "$line" | awk '{$1=""; print $0}')
        if [[ "$key" == "$current_model" ]]; then
            menu_items+=("$key" "$value" "on")
        else
            menu_items+=("$key" "$value" "off")
        fi
    done <<< "$options"

    selected_model=$(dialog --radiolist "Select a model to download" ${DIALOG_HEIGHT} ${DIALOG_WIDTH} 5 "${menu_items[@]}" 3>&1 1>&2 2>&3)
    if [[ -z "$selected_model" ]]; then
        print_error "No model selected. Exiting."
        exit 1
    fi
    model="$selected_model"

    # Select size if available
    sizes=$(jq -r --arg model "$model" '.[] | select(.name == $model) | .sizes[]' "$MODEL_FILE" 2>/dev/null || true)
    if [[ -n "$sizes" && "$sizes" != "null" ]]; then
        menu_items=()
        while IFS= read -r sz; do
            menu_items+=("$sz" "$sz")
        done <<< "$sizes"
        size=$(dialog --menu "Select a size for: ${model}" ${DIALOG_HEIGHT} ${DIALOG_WIDTH} 5 "${menu_items[@]}" 3>&1 1>&2 2>&3)
    fi
fi

# Derive URL if only model provided
if [[ -z "$url" && -n "$model" ]]; then
    url="https://ollama.com/models/${model}.tar.gz"
fi

# Default destination directory
if [[ -z "$dir" ]]; then
    base="./models"
    if [[ -n "$size" ]]; then
        dir="${base}/${model}-${size}"
    else
        dir="${base}/${model}"
    fi
fi

# Check if the directory exists
if [ ! -d "$dir" ]; then
    echo "Directory $dir does not exist. Creating..."
    mkdir -p "$dir"
fi

# Download the model
echo "Downloading model ${model:-from-url} from $url to $dir"

# Download to temp and verify format
tmpfile=$(mktemp)
if ! curl -fsSL -o "$tmpfile" "$url"; then
    echo "Failed to download from $url"
    download_ok=0
else
    # Verify gzip format (prefer gzip -t; avoids relying on 'file')
    if gzip -t "$tmpfile" >/dev/null 2>&1; then
        mkdir -p "$dir"
        if tar -xzf "$tmpfile" -C "$dir"; then
            echo "Model $model downloaded and extracted to $dir."
            download_ok=1
        else
            echo "Archive extraction failed."
            download_ok=0
        fi
    else
        echo "Downloaded file is not a gzip archive; direct URL likely unsupported for this model."
        download_ok=0
    fi
fi

rm -f "$tmpfile"

if [ "${download_ok:-0}" -ne 1 ]; then
    # Fallback: use Ollama to pull and export if available
    if command -v ollama >/dev/null 2>&1; then
        tag=${size:-latest}
        echo "Attempting fallback via 'ollama pull' for ${model}:${tag}..."
        if ollama pull "${model}:${tag}"; then
            # Try export if supported
            if ollama help 2>&1 | grep -iq "export"; then
                outbase="${dir}/${model}-${tag}"
                mkdir -p "$dir"
                if ollama export "${model}:${tag}" > "${outbase}.ollama"; then
                    echo "Exported model to ${outbase}.ollama"
                    exit 0
                else
                    echo "Ollama export failed; model pulled but not exported."
                    exit 1
                fi
            else
                echo "'ollama export' not available. Model pulled locally; reuse via Ollama cache."
                exit 0
            fi
        else
            echo "Ollama pull failed for ${model}:${tag}."
            exit 1
        fi
    else
        echo "Cannot fallback: 'ollama' CLI not available."
        exit 1
    fi
fi

# End of script
