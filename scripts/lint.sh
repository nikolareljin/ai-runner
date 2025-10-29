#!/usr/bin/env bash
set -euo pipefail

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "ShellCheck not found. Install with:"
  echo "  - macOS:   brew install shellcheck"
  echo "  - Ubuntu:  sudo apt-get update && sudo apt-get install -y shellcheck"
  exit 1
fi

# Collect tracked shell scripts
readarray -t FILES < <(git ls-files '*.sh')

if [ -z "${FILES}" ]; then
  echo "No shell scripts found."
  exit 0
fi

echo "Running ShellCheck on:"
for f in "${FILES[@]}"; do
  echo " - $f"
done

# STRICT=1 will make failures exit non-zero; default is soft-fail
STRICT=${STRICT:-0}

if [ "${STRICT}" = "1" ]; then
  shellcheck -S style -x -e SC1091 "${FILES[@]}"
else
  shellcheck -S style -x -e SC1091 "${FILES[@]}" || true
  echo "(Warnings are not failing the build; run with STRICT=1 to enforce)"
fi
