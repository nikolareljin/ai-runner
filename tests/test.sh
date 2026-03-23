#!/usr/bin/env bash
# SCRIPT: test.sh
# DESCRIPTION: Run the shell-based ai-runner smoke test suite.
# USAGE: bash tests/test.sh [-h]
# PARAMETERS:
# -h                : show help
# EXAMPLE: bash tests/test.sh
# ----------------------------------------------------
set -euo pipefail

help() {
    cat <<'EOF'
Run the shell-based ai-runner smoke tests.

Usage:
  bash tests/test.sh [-h]

Options:
  -h    Show help

Current coverage:
  - tests/test-chat-completions.sh
  - tests/test-get-fallback-messages.sh
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

printf 'Running shell smoke tests...\n'
bash "$SCRIPT_DIR/test-chat-completions.sh"
bash "$SCRIPT_DIR/test-get-fallback-messages.sh"
printf 'Shell smoke tests completed.\n'
