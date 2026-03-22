#!/usr/bin/env bash
# SCRIPT: test-get-fallback-messages.sh
# DESCRIPTION: Verify fallback success messages when Ollama export is unavailable.
# USAGE: bash tests/test-get-fallback-messages.sh [-h]
# PARAMETERS:
# -h                : show help
# EXAMPLE: bash tests/test-get-fallback-messages.sh
# ----------------------------------------------------
set -euo pipefail

help() {
    cat <<'EOF'
Verify fallback success messaging for ./get when Ollama export is unavailable.

Usage:
  bash tests/test-get-fallback-messages.sh [-h]

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=/dev/null
source "$PROJECT_ROOT/scripts/include.sh"

models_dir="${PROJECT_ROOT}/models"
docker_same="$(ollama_export_unavailable_message docker "./models/" "$models_dir")"
docker_diff="$(ollama_export_unavailable_message docker "./models/custom" "$models_dir")"
local_same="$(ollama_export_unavailable_message local "./models/" "$models_dir")"
local_diff="$(ollama_export_unavailable_message local "./models/custom" "$models_dir")"

[[ "$docker_same" == *"the runtime model store is ${models_dir}."* ]]
[[ "$docker_diff" == *"no archive was written to ./models/custom."* ]]
[[ "$docker_diff" == *"Docker runtime store at ${models_dir}."* ]]
[[ "$local_same" == *"the local runtime model store is ${models_dir}."* ]]
[[ "$local_diff" == *"no archive was written to ./models/custom."* ]]
[[ "$local_diff" == *"local Ollama model store at ${models_dir}."* ]]
