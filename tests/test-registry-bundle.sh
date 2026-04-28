#!/usr/bin/env bash
# SCRIPT: test-registry-bundle.sh
# DESCRIPTION: Verify Ollama registry bundle download layout and overwrite safety.
# USAGE: bash tests/test-registry-bundle.sh [-h]
# PARAMETERS:
# -h                : show help
# EXAMPLE: bash tests/test-registry-bundle.sh
# ----------------------------------------------------
set -euo pipefail

help() {
    cat <<'EOF'
Verify registry bundle layout and destination overwrite safety for ./get.

Usage:
  bash tests/test-registry-bundle.sh [-h]

Options:
  -h    Show help
EOF
}

while getopts ":h" opt; do
    case "${opt}" in
        h)
            help
            exit 0
            ;;
        \?)
            printf 'Invalid option: -%s\n\n' "$OPTARG" >&2
            help >&2
            exit 1
            ;;
    esac
done

shift "$((OPTIND - 1))"

if [ "$#" -ne 0 ]; then
    printf 'Unexpected positional arguments: %s\n\n' "$*" >&2
    help >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    printf "Skipping registry bundle test: jq is not installed.\n" >&2
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

AI_RUNNER_GET_SOURCE_ONLY=1 source "$PROJECT_ROOT/scripts/get.sh"

assert_file_exists() {
    local path=$1
    local label=$2

    if [[ ! -f "$path" ]]; then
        printf 'Assertion failed: %s\nExpected file: %s\n' "$label" "$path" >&2
        exit 1
    fi
}

assert_file_contains() {
    local path=$1
    local expected=$2
    local label=$3

    if [[ "$(cat "$path")" != "$expected" ]]; then
        printf 'Assertion failed: %s\nExpected content: %s\nActual content: %s\n' "$label" "$expected" "$(cat "$path")" >&2
        exit 1
    fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fixture_dir="${tmp_dir}/fixtures"
mkdir -p "$fixture_dir"
config_blob="${fixture_dir}/config"
layer_blob="${fixture_dir}/layer"
manifest_fixture="${fixture_dir}/manifest.json"
printf 'config-json' > "$config_blob"
printf 'layer-bytes' > "$layer_blob"
config_hash="$(sha256_file "$config_blob")"
layer_hash="$(sha256_file "$layer_blob")"

jq -n \
    --arg config_digest "sha256:${config_hash}" \
    --arg layer_digest "sha256:${layer_hash}" \
    '{
        schemaVersion: 2,
        config: {mediaType: "application/vnd.ollama.config", digest: $config_digest, size: 11},
        layers: [{mediaType: "application/vnd.ollama.layer", digest: $layer_digest, size: 11}]
    }' > "$manifest_fixture"

download_file() {
    local url=$1
    local output=$2

    case "$url" in
        */manifests/latest)
            cp "$manifest_fixture" "$output"
            ;;
        *"sha256:${config_hash}")
            cp "$config_blob" "$output"
            ;;
        *"sha256:${layer_hash}")
            cp "$layer_blob" "$output"
            ;;
        *)
            printf 'Unexpected download URL: %s\n' "$url" >&2
            return 1
            ;;
    esac
}

destination="${tmp_dir}/bundle"
download_ollama_registry_bundle "llama3" "latest" "$destination"

assert_file_exists "${destination}/manifest.json" "manifest is written"
assert_file_exists "${destination}/bundle-metadata.json" "metadata is written"
assert_file_exists "${destination}/blobs/sha256-${config_hash}" "config blob is written by digest"
assert_file_exists "${destination}/blobs/sha256-${layer_hash}" "layer blob is written by digest"
assert_file_contains "${destination}/blobs/sha256-${config_hash}" "config-json" "config blob content"
assert_file_contains "${destination}/blobs/sha256-${layer_hash}" "layer-bytes" "layer blob content"

metadata_format="$(jq -r '.format' "${destination}/bundle-metadata.json")"
if [[ "$metadata_format" != "ollama-registry-bundle" ]]; then
    printf 'Expected bundle metadata format, got: %s\n' "$metadata_format" >&2
    exit 1
fi

protected_destination="${tmp_dir}/protected"
mkdir -p "${protected_destination}/blobs"
printf 'keep-me' > "${protected_destination}/blobs/unrelated"
if download_ollama_registry_bundle "llama3" "latest" "$protected_destination" >/dev/null 2>&1; then
    printf 'Expected registry bundle download to refuse an existing blobs directory.\n' >&2
    exit 1
fi
assert_file_contains "${protected_destination}/blobs/unrelated" "keep-me" "pre-existing blobs content is preserved"

run_output="$("$PROJECT_ROOT/run" </dev/null 2>&1 || true)"
if [[ "$run_output" != *"Non-interactive mode requires -m <model> and -p <prompt>."* ]]; then
    printf 'Expected ./run with no TTY and no args to fail before opening dialog. Got: %s\n' "$run_output" >&2
    exit 1
fi
