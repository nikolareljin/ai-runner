#!/usr/bin/env bash
# SCRIPT: example.sh
# DESCRIPTION: Bootstrap the Next.js demo with the Vercel AI example.
# USAGE: ./example.sh [-h]
# PARAMETERS:
# -h                : show help
# EXAMPLE: ./example.sh
# ----------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$SCRIPT_DIR/scripts/script-helpers}"
# shellcheck source=/dev/null
source "$SCRIPT_HELPERS_DIR/helpers.sh"
shlib_import logging deps help

help() { display_help "$0"; }

while getopts ":h" opt; do
    case ${opt} in
        h) help; exit 0 ;;
        \?) print_error "Invalid option: -$OPTARG"; help; exit 1 ;;
    esac
done

install_dependencies_ai_runner

npx create-next-app --example https://github.com/vercel/ai/tree/main/examples/next-openai example
cd example
npm install @vercel/ai

print_info "Next: add your API route under app/api/chat/route.ts"
