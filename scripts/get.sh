#!/usr/bin/env bash
# SCRIPT: get.sh
# DESCRIPTION: Download a model archive for offline reuse.
# USAGE: ./get.sh [-h] [-m <model>] [-u <url>] [-d <dir>] [-r <runtime>]
# PARAMETERS:
# -m <model>        : model name (default: current selection or prompt)
# -u <url>          : model URL (if not in the list)
# -d <dir>          : directory to download the model to (default: ./models/<model>-<size>)
# -r <runtime>      : runtime to use for fallback pull/export (local|docker)
# -h                : show help
# EXAMPLE: ./get.sh -m llama3 -d ./models -r docker
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
MODEL_REPO_DIR="$ROOT_DIR/ollama-get-models"
json_file=""

help() { display_help "$0"; }

sanitize_filename_component() {
    local value="$1"

    value="$(printf "%s" "$value" | sed -E 's/[^A-Za-z0-9._-]+/_/g')"
    value="$(printf "%s" "$value" | sed -E 's/\.\.+/_/g; s/^[-._]+//; s/[-._]+$//')"
    if [[ -z "$value" ]]; then
        value="unknown"
    fi
    printf "%s\n" "$value"
}

validate_tar_archive_safety() {
    local archive_path="$1"
    local entry
    local perms
    local type_char
    local -a entries=()
    local -a verbose_entries=()

    if ! mapfile -t entries < <(tar -tzf "$archive_path"); then
        print_error "Failed to inspect archive: $archive_path"
        return 1
    fi

    for entry in "${entries[@]}"; do
        [[ -n "$entry" ]] || continue
        entry="${entry#./}"
        if [[ "$entry" == /* ]] || [[ "$entry" =~ (^|/)\.\.(/|$) ]]; then
            print_error "Unsafe archive entry detected: $entry"
            return 1
        fi
    done

    if ! mapfile -t verbose_entries < <(tar -tvzf "$archive_path"); then
        print_error "Failed to perform verbose inspection of archive: $archive_path"
        return 1
    fi

    for entry in "${verbose_entries[@]}"; do
        [[ -n "$entry" ]] || continue
        perms="${entry%% *}"
        [[ -n "$perms" ]] || continue
        type_char="${perms:0:1}"
        if [[ "$type_char" == "l" || "$type_char" == "h" ]]; then
            print_error "Unsafe link entry detected in archive: $entry"
            return 1
        elif [[ "$type_char" == "c" || "$type_char" == "b" || "$type_char" == "p" || "$type_char" == "s" ]]; then
            print_error "Unsafe special file entry detected in archive: $entry"
            return 1
        fi
    done
}

get_select_model_any() {
    local json_file="$1"
    local current_model="${2:-}"
    local current_size="${3:-latest}"
    local mode model_value size_value

    dialog_init
    check_if_dialog_installed

    if ! mode=$(dialog --stdout --menu "Select model source" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 10 \
        "indexed" "Choose from indexed Ollama models" \
        "manual" "Enter any model name manually"); then
        print_error "Model selection cancelled."
        return 1
    fi

    if [[ "$mode" == "indexed" ]]; then
        model_value="$(ollama_dialog_select_model "$json_file" "$current_model")" || return 1
        size_value="$(ollama_dialog_select_size "$json_file" "$model_value" "$current_size")" || return 1
        printf '%s\n%s\n' "$model_value" "$size_value"
        return 0
    fi

    model_value="$(get_value "Model Name" "Enter any Ollama model name (example: deepseek-ocr)" "$current_model")" || return 1
    model_value="$(printf '%s' "$model_value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    if [[ -z "$model_value" ]]; then
        print_error "Model name cannot be empty."
        return 1
    fi

    size_value="$(get_value "Model Size/Tag" "Enter size/tag (example: 3b). Use latest for default." "$current_size")" || return 1
    size_value="$(printf '%s' "${size_value:-latest}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [[ -z "$size_value" ]] && size_value="latest"
    printf '%s\n%s\n' "$model_value" "$size_value"
}

model=""
size=""
url=""
dir=""
runtime_override=""

while getopts ":hm:u:d:r:" opt; do
    case ${opt} in
        h) help; exit 0 ;;
        m) model="$OPTARG" ;;
        u) url="$OPTARG" ;;
        d) dir="$OPTARG" ;;
        r) runtime_override="$OPTARG" ;;
        :) print_error "Option -$OPTARG requires an argument"; exit 1 ;;
        \?) print_error "Invalid option: -$OPTARG"; help; exit 1 ;;
    esac
done

if [[ -f "$ENV_FILE" ]]; then
    load_env "$ENV_FILE"
    ollama_runtime_sync_env_url "$ENV_FILE" >/dev/null
fi
runtime="$(ollama_runtime_type "$ENV_FILE" "$runtime_override")"

if [[ -n "$model" && "$model" == *:* && -z "$size" ]]; then
    size="${model#*:}"
    model="${model%%:*}"
fi

if [[ -t 0 && -t 1 && -z "$model" && -z "$url" ]]; then
    json_file="$(ollama_models_json_path "$MODEL_REPO_DIR")"
    if [[ ! -f "$json_file" ]]; then
        print_info "Model index not found. Preparing..."
        json_file="$(ollama_prepare_models_index "$MODEL_REPO_DIR")"
    fi

    current_model="${model:-$(resolve_env_value "model" "" "$ENV_FILE")}"
    current_size="$(resolve_env_value "size" "latest" "$ENV_FILE")"
    [[ -n "$size" ]] && current_size="$size"
    mapfile -t selection_lines < <(get_select_model_any "$json_file" "$current_model" "$current_size") || exit 1
    if [[ "${#selection_lines[@]}" -lt 2 ]]; then
        print_error "Model selection failed."
        exit 1
    fi
    model="${selection_lines[0]}"
    size="${selection_lines[1]}"
    url=""
elif [[ -z "$model" && -z "$url" ]]; then
    print_error "Non-interactive mode requires -m <model> or -u <url>."
    exit 1
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
download_extracted=false
if DIALOG_DOWNLOAD_SHOW_ERROR_DIALOG=0 download_file "$url" "$tmpfile"; then
    if gzip -t "$tmpfile" >/dev/null 2>&1; then
        if validate_tar_archive_safety "$tmpfile" && tar --no-same-owner --no-same-permissions -xzf "$tmpfile" -C "$dir"; then
            print_success "Model ${model:-archive} extracted to $dir."
            download_extracted=true
        else
            print_error "Archive extraction failed."
        fi
    else
        print_warning "Downloaded file is not a gzip archive; direct URL likely unsupported for this model."
    fi
else
    print_warning "Direct archive download failed for $url; trying runtime fallback."
fi

rm -f "$tmpfile"
if [[ "$download_extracted" == "true" ]]; then
    exit 0
fi

if [[ -n "$model" ]]; then
    tag="${size:-latest}"
    model_ref="$(ollama_model_ref "$model" "$tag")"
    if [[ "$runtime" == "docker" ]]; then
        ollama_runtime_ensure_ready "$runtime" "$ENV_FILE"
    fi
    print_info "Attempting fallback via '$runtime' runtime pull for ${model_ref}..."
    if ollama_runtime_pull_model "$runtime" "$ENV_FILE" "$model" "$tag"; then
        if ollama_runtime_supports_export "$runtime" "$ENV_FILE"; then
            safe_model="$(sanitize_filename_component "$model")"
            safe_tag="$(sanitize_filename_component "$tag")"
            outbase="${dir}/${safe_model}-${safe_tag}"
            if ollama_runtime_export_model "$runtime" "$ENV_FILE" "$model_ref" "${outbase}.ollama"; then
                print_success "Exported model to ${outbase}.ollama"
                exit 0
            else
                print_error "Ollama export failed; model pulled but not exported."
                exit 1
            fi
        else
            if [[ "$runtime" == "docker" ]]; then
                cache_dir="$(ollama_runtime_data_dir "$ENV_FILE")"
                print_success "Model pulled successfully. This Ollama build does not support 'ollama export'; model is available in ${cache_dir}."
            else
                cache_dir="$(ollama_runtime_local_models_dir "$ENV_FILE")"
                print_success "Model pulled successfully. This Ollama build does not support 'ollama export'; model is available in ${cache_dir}."
            fi
            exit 0
        fi
    else
        print_error "Ollama pull failed for ${model_ref} using runtime '$runtime'."
        exit 1
    fi
else
    print_error "Cannot fallback: model not set."
    exit 1
fi
