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
    if ! command -v python3 >/dev/null 2>&1; then
        print_warning "python3 not found; using basic tar archive safety checks."
        if ! command -v tar >/dev/null 2>&1; then
            print_error "tar is required to validate archive safety."
            return 1
        fi

        local entry name
        while IFS= read -r entry; do
            name="$entry"
            while [[ "$name" == ./* ]]; do
                name="${name#./}"
            done
            if [[ -z "$name" || "$name" == /* || "$name" == ".." || "$name" == ../* || "$name" == */.. || "$name" == */../* ]]; then
                print_error "Unsafe archive entry detected: $entry"
                return 1
            fi
        done < <(tar -tzf "$archive_path")
        return 0
    fi

    if ! python3 - "$archive_path" <<'PY'
import pathlib
import sys
import tarfile

archive = sys.argv[1]
try:
    with tarfile.open(archive, "r:gz") as tf:
        for member in tf:
            original_name = member.name
            name = original_name
            while name.startswith("./"):
                name = name[2:]
            if not name:
                raise ValueError(f"unsafe archive entry: {member.name}")
            p = pathlib.PurePosixPath(name)
            if p.is_absolute() or ".." in p.parts:
                raise ValueError(f"unsafe archive path: {member.name}")
            if member.issym() or member.islnk():
                raise ValueError(f"unsafe link entry: {member.name}")
            if member.ischr() or member.isblk() or member.isfifo():
                raise ValueError(f"unsafe special entry: {member.name}")
            if hasattr(member, "issock") and member.issock():
                raise ValueError(f"unsafe special entry: {member.name}")
except Exception as exc:
    print(str(exc), file=sys.stderr)
    sys.exit(1)
PY
    then
        print_error "Archive safety validation failed for: $archive_path"
        return 1
    fi

    return 0
}

get_select_model_any() {
    local json_file="$1"
    local current_model="${2:-}"
    local current_size="${3:-latest}"
    local model_value size_value status

    while true; do
        if ! model_value="$(ollama_dialog_select_model "$json_file" "$current_model")"; then
            status=$?
            return "$status"
        fi
        if size_value="$(ollama_dialog_select_size "$json_file" "$model_value" "$current_size")"; then
            printf '%s\n%s\n' "$model_value" "$size_value"
            return 0
        fi
        status=$?
        if [[ $status -eq 2 ]]; then
            current_model="$model_value"
            continue
        fi
        return "$status"
    done
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

runtime_override="$(normalize_runtime_override "$runtime_override")"

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
    if ! menu_cache_file="$(require_model_menu_cache_file "$json_file")"; then
        status=$?
        exit "$status"
    fi

    current_model="${model:-$(resolve_env_value "model" "" "$ENV_FILE")}"
    current_size="$(resolve_env_value "size" "latest" "$ENV_FILE")"
    [[ -n "$size" ]] && current_size="$size"
    if ! selection_output="$(get_select_model_any "$json_file" "$current_model" "$current_size")"; then
        exit 1
    fi
    mapfile -t selection_lines <<< "$selection_output"
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

if [[ -z "$dir" ]]; then
    base="$ROOT_DIR/models"
    safe_model_dir="$(sanitize_filename_component "${model:-archive}")"
    if [[ -n "$size" ]]; then
        safe_size_dir="$(sanitize_filename_component "$size")"
        dir="${base}/${safe_model_dir}-${safe_size_dir}"
    else
        dir="${base}/${safe_model_dir}"
    fi
fi

create_directory "$dir" >/dev/null

print_info "Downloading model ${model:-from-url} from $url to $dir"

tmpfile=$(mktemp)
download_extracted=false
if [[ -z "$url" ]]; then
    print_info "No direct archive URL available; skipping direct download and using runtime fallback."
elif DIALOG_DOWNLOAD_SHOW_ERROR_DIALOG=0 download_file "$url" "$tmpfile"; then
    if gzip -t "$tmpfile" >/dev/null 2>&1; then
        if validate_tar_archive_safety "$tmpfile"; then
            extract_stage_dir="$(mktemp -d)"
            if tar --no-same-owner --no-same-permissions -xzf "$tmpfile" -C "$extract_stage_dir"; then
                if cp -R "$extract_stage_dir"/. "$dir"/; then
                    print_success "Model ${model:-archive} extracted to $dir."
                    download_extracted=true
                else
                    print_error "Failed to apply extracted archive content into $dir."
                    rm -rf "$extract_stage_dir"
                    rm -f "$tmpfile"
                    exit 1
                fi
            else
                print_error "Archive extraction failed."
                rm -rf "$extract_stage_dir"
                rm -f "$tmpfile"
                exit 1
            fi
            rm -rf "$extract_stage_dir"
        else
            print_error "Archive extraction skipped due to failed safety validation."
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
                print_success "$(ollama_export_unavailable_message "$runtime" "$dir" "$cache_dir")"
            else
                cache_dir="$(ollama_runtime_local_models_dir "$ENV_FILE")"
                print_success "$(ollama_export_unavailable_message "$runtime" "$dir" "$cache_dir")"
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
