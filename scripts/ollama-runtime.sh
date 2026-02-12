#!/usr/bin/env bash
# Shared Ollama runtime helpers for local CLI and Docker runtime.

ollama_model_ref_safe() {
    local model_name="$1"
    local model_size="${2:-latest}"
    if [[ -z "$model_size" || "$model_size" == "latest" ]]; then
        echo "$model_name"
    else
        echo "${model_name}:${model_size}"
    fi
}

ollama_runtime_type() {
    local env_file="$1"
    local runtime_override="${2:-}"
    local runtime

    if [[ -n "$runtime_override" ]]; then
        runtime="$runtime_override"
    else
        runtime="$(resolve_env_value "ollama_runtime" "local" "$env_file")"
    fi

    runtime="$(echo "$runtime" | tr '[:upper:]' '[:lower:]')"
    if [[ "$runtime" != "local" && "$runtime" != "docker" ]]; then
        print_warning "Invalid ollama_runtime '$runtime'; defaulting to 'local'."
        runtime="local"
    fi

    echo "$runtime"
}

ollama_runtime_scheme() {
    local env_file="$1"
    resolve_env_value "ollama_scheme" "http" "$env_file"
}

ollama_runtime_host() {
    local env_file="$1"
    resolve_env_value "ollama_host" "localhost" "$env_file"
}

ollama_runtime_port() {
    local env_file="$1"
    resolve_env_value "ollama_port" "11434" "$env_file"
}

ollama_runtime_build_base_url() {
    local env_file="$1"
    local scheme host port base

    scheme="$(ollama_runtime_scheme "$env_file")"
    host="$(ollama_runtime_host "$env_file")"
    port="$(ollama_runtime_port "$env_file")"

    host="${host%/}"
    if [[ "$host" == *"://"* ]]; then
        base="$host"
    else
        base="${scheme}://${host}"
    fi

    if [[ ! "$base" =~ :[0-9]+$ ]]; then
        base="${base}:${port}"
    fi

    echo "${base%/}"
}

ollama_runtime_sync_env_url() {
    local env_file="$1"
    local base_url

    base_url="$(ollama_runtime_build_base_url "$env_file")"
    if [[ -n "$env_file" ]]; then
        ollama_update_env "$env_file" ollama_url "$base_url"
    fi
    echo "$base_url"
}

ollama_runtime_api_base_url() {
    local env_file="$1"
    local base_url
    local host_value

    host_value="$(resolve_env_value "ollama_host" "" "$env_file")"
    if [[ -n "$host_value" ]]; then
        base_url="$(ollama_runtime_build_base_url "$env_file")"
    else
        base_url="$(resolve_env_value "ollama_url" "" "$env_file")"
    fi
    if [[ -z "$base_url" ]]; then
        local website
        website="$(resolve_env_value "website" "http://localhost:11434/api/generate" "$env_file")"
        base_url="${website%/api/generate}"
    fi

    base_url="${base_url%/}"
    if [[ -z "$base_url" ]]; then
        base_url="http://localhost:11434"
    fi

    echo "$base_url"
}

ollama_runtime_generate_endpoint() {
    local env_file="$1"
    echo "$(ollama_runtime_api_base_url "$env_file")/api/generate"
}

ollama_runtime_container_name() {
    local env_file="$1"
    resolve_env_value "ollama_docker_container" "ai-runner-ollama" "$env_file"
}

ollama_runtime_image() {
    local env_file="$1"
    resolve_env_value "ollama_docker_image" "ollama/ollama:latest" "$env_file"
}

ollama_runtime_data_dir() {
    local env_file="$1"
    local data_dir

    data_dir="$(resolve_env_value "ollama_data_dir" "./models/ollama-data" "$env_file")"
    if [[ "$data_dir" != /* ]]; then
        data_dir="$ROOT_DIR/$data_dir"
    fi

    create_directory "$data_dir" >/dev/null
    (cd "$data_dir" && pwd)
}

ollama_runtime_local_models_dir() {
    local env_file="$1"
    local shared_store local_models_dir data_dir

    shared_store="$(resolve_env_value "ollama_shared_model_store" "1" "$env_file")"
    shared_store="$(echo "$shared_store" | tr '[:upper:]' '[:lower:]')"
    if [[ "$shared_store" == "1" || "$shared_store" == "true" || "$shared_store" == "yes" ]]; then
        data_dir="$(ollama_runtime_data_dir "$env_file")"
        local_models_dir="${data_dir}/models"
    else
        local_models_dir="$(resolve_env_value "ollama_local_models_dir" "${OLLAMA_MODELS:-$HOME/.ollama/models}" "$env_file")"
    fi

    if [[ "$local_models_dir" != /* ]]; then
        local_models_dir="$ROOT_DIR/$local_models_dir"
    fi
    create_directory "$local_models_dir" >/dev/null
    (cd "$local_models_dir" && pwd)
}

ollama_runtime_local_cmd() {
    local env_file="$1"
    shift
    local local_models_dir
    local_models_dir="$(ollama_runtime_local_models_dir "$env_file")"
    OLLAMA_MODELS="$local_models_dir" ollama "$@"
}

ollama_runtime_host_port() {
    local base_url="$1"
    if [[ "$base_url" =~ :([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "11434"
    fi
}

ollama_runtime_ensure_docker_container() {
    local env_file="$1"
    local container image data_dir base_url host_port

    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker runtime selected but 'docker' CLI is not available."
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        print_error "Docker runtime selected but Docker daemon is not reachable."
        return 1
    fi

    container="$(ollama_runtime_container_name "$env_file")"
    image="$(ollama_runtime_image "$env_file")"
    data_dir="$(ollama_runtime_data_dir "$env_file")"
    base_url="$(ollama_runtime_api_base_url "$env_file")"
    host_port="$(ollama_runtime_host_port "$base_url")"

    if docker ps --filter "name=^/${container}$" --filter "status=running" -q | grep -q .; then
        return 0
    fi

    if docker ps -a --filter "name=^/${container}$" -q | grep -q .; then
        print_info "Starting Docker Ollama container: ${container}"
        docker start "$container" >/dev/null
        return 0
    fi

    print_info "Creating Docker Ollama container '${container}' from ${image}"
    print_info "Mounting model data: ${data_dir} -> /root/.ollama"
    docker run -d \
        --name "$container" \
        -p "${host_port}:11434" \
        -v "${data_dir}:/root/.ollama" \
        "$image" >/dev/null
}

ollama_runtime_ensure_ready() {
    local runtime="$1"
    local env_file="$2"

    if [[ "$runtime" == "docker" ]]; then
        ollama_runtime_ensure_docker_container "$env_file"
    fi
}

ollama_runtime_pull_model() {
    local runtime="$1"
    local env_file="$2"
    local model="$3"
    local size="${4:-latest}"
    local model_ref

    model_ref="$(ollama_model_ref_safe "$model" "$size")"
    if [[ "$runtime" == "docker" ]]; then
        local container
        ollama_runtime_ensure_docker_container "$env_file" || return 1
        container="$(ollama_runtime_container_name "$env_file")"
        print_info "Pulling model in Docker: ${model_ref}"
        docker exec "$container" ollama pull "$model_ref"
        return $?
    fi

    if ! command -v ollama >/dev/null 2>&1; then
        print_error "ollama CLI not found; install it or set ollama_runtime=docker."
        return 1
    fi

    print_info "Pulling model locally: ${model_ref}"
    ollama_runtime_local_cmd "$env_file" pull "$model_ref"
}

ollama_runtime_supports_export() {
    local runtime="$1"
    local env_file="$2"
    local out=""
    local rc=0

    if [[ "$runtime" == "docker" ]]; then
        local container
        ollama_runtime_ensure_docker_container "$env_file" || return 1
        container="$(ollama_runtime_container_name "$env_file")"
        out="$(docker exec "$container" ollama export --help 2>&1)" || rc=$?
    else
        if ! command -v ollama >/dev/null 2>&1; then
            return 1
        fi
        out="$(ollama_runtime_local_cmd "$env_file" export --help 2>&1)" || rc=$?
    fi

    if [[ $rc -eq 0 ]]; then
        return 0
    fi

    # Some builds return non-zero for help; detect true "unknown command" cases.
    if echo "$out" | grep -Eiq "unknown command|not a valid command|No help topic"; then
        return 1
    fi
    if echo "$out" | grep -Eiq "usage:|ollama export"; then
        return 0
    fi
    return 1
}

ollama_runtime_export_model() {
    local runtime="$1"
    local env_file="$2"
    local model_ref="$3"
    local output_path="$4"

    if [[ "$runtime" == "docker" ]]; then
        local container
        ollama_runtime_ensure_docker_container "$env_file" || return 1
        container="$(ollama_runtime_container_name "$env_file")"
        docker exec "$container" ollama export "$model_ref" > "$output_path"
        return $?
    fi

    if ! command -v ollama >/dev/null 2>&1; then
        print_error "ollama CLI not found; cannot export model."
        return 1
    fi

    ollama_runtime_local_cmd "$env_file" export "$model_ref" > "$output_path"
}

ollama_runtime_run_model() {
    local runtime="$1"
    local env_file="$2"
    local model="$3"
    local size="${4:-latest}"
    local model_ref

    if [[ "$runtime" == "docker" ]]; then
        return 0
    fi

    if ! command -v ollama >/dev/null 2>&1; then
        print_error "ollama CLI not found; cannot run model locally."
        return 1
    fi

    model_ref="$(ollama_model_ref_safe "$model" "$size")"
    nohup bash -lc "OLLAMA_MODELS=\"$(ollama_runtime_local_models_dir "$env_file")\" ollama run \"$model_ref\"" >/dev/null 2>&1 &
}

ollama_runtime_ps() {
    local runtime="$1"
    local env_file="$2"

    if [[ "$runtime" == "docker" ]]; then
        local container
        container="$(ollama_runtime_container_name "$env_file")"
        if docker ps --filter "name=^/${container}$" --filter "status=running" -q | grep -q .; then
            docker exec "$container" ollama ps || true
        fi
        return 0
    fi

    if command -v ollama >/dev/null 2>&1; then
        ollama_runtime_local_cmd "$env_file" ps || true
    fi
}
