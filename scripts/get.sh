#!/usr/bin/env bash
# SCRIPT: get.sh
# DESCRIPTION: Download a model archive for offline reuse.
# USAGE: ./get.sh [-h] [-m <model>] [-u <url>] [-d <dir>]
# PARAMETERS:
# -m <model>        : model name (default: current selection or prompt)
# -u <url>          : model URL (if not in the list)
# -d <dir>          : directory to download the model to (default: ./models/<model>-<size>)
# -h                : show help
# EXAMPLE: ./get.sh -m llama3 -d ./models
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
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$ROOT_DIR/scripts/script-helpers}"
# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging dialog os env json file deps ollama help clipboard

ENV_FILE="$ROOT_DIR/.env"
MODEL_REPO_DIR="$ROOT_DIR/ollama-get-models"

help() { display_help "$0"; }

model=""
size=""
url=""
dir=""

while getopts ":hm:u:d:" opt; do
    case ${opt} in
        h) help; exit 0 ;;
        m) model="$OPTARG" ;;
        u) url="$OPTARG" ;;
        d) dir="$OPTARG" ;;
        :) print_error "Option -$OPTARG requires an argument"; exit 1 ;;
        \?) print_error "Invalid option: -$OPTARG"; help; exit 1 ;;
    esac
done

if [[ -f "$ENV_FILE" ]]; then
    load_env "$ENV_FILE"
fi

if [[ -z "$model" && -z "$url" ]]; then
    json_file="$(ollama_models_json_path "$MODEL_REPO_DIR")"
    if [[ ! -f "$json_file" ]]; then
        print_info "Model index not found. Preparing..."
        json_file="$(ollama_prepare_models_index "$MODEL_REPO_DIR")"
    fi

    current_model="$(resolve_env_value "model" "" "$ENV_FILE")"
    model="$(ollama_dialog_select_model "$json_file" "$current_model")"

    current_size="$(resolve_env_value "size" "latest" "$ENV_FILE")"
    size="$(ollama_dialog_select_size "$json_file" "$model" "$current_size")"
fi

if [[ -z "$url" && -n "$model" ]]; then
    url="https://ollama.com/models/${model}.tar.gz"
fi

if [[ -z "$url" ]]; then
    print_error "No URL provided or derived."
    exit 1
fi

if [[ -z "$dir" ]]; then
    base="$ROOT_DIR/models"
    if [[ -n "$size" ]]; then
        dir="${base}/${model}-${size}"
    else
        dir="${base}/${model}"
    fi
fi

create_directory "$dir" >/dev/null

print_info "Downloading model ${model:-from-url} from $url to $dir"

tmpfile=$(mktemp)
if download_file "$url" "$tmpfile"; then
    if gzip -t "$tmpfile" >/dev/null 2>&1; then
        if tar -xzf "$tmpfile" -C "$dir"; then
            print_success "Model ${model:-archive} extracted to $dir."
            rm -f "$tmpfile"
            exit 0
        else
            print_error "Archive extraction failed."
        fi
    else
        print_error "Downloaded file is not a gzip archive; direct URL likely unsupported for this model."
    fi
else
    print_error "Failed to download from $url"
fi

rm -f "$tmpfile"

if command -v ollama >/dev/null 2>&1 && [[ -n "$model" ]]; then
    tag="${size:-latest}"
    print_info "Attempting fallback via 'ollama pull' for ${model}:${tag}..."
    if ollama_pull_model "$model" "$tag"; then
        if ollama help 2>&1 | grep -iq "export"; then
            outbase="${dir}/${model}-${tag}"
            if ollama export "${model}:${tag}" > "${outbase}.ollama"; then
                print_success "Exported model to ${outbase}.ollama"
                exit 0
            else
                print_error "Ollama export failed; model pulled but not exported."
                exit 1
            fi
        else
            print_warning "'ollama export' not available. Model pulled locally; reuse via Ollama cache."
            exit 0
        fi
    else
        print_error "Ollama pull failed for ${model}:${tag}."
        exit 1
    fi
else
    print_error "Cannot fallback: 'ollama' CLI not available or model not set."
    exit 1
fi
