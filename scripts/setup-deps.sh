#!/usr/bin/env bash
# SCRIPT: setup-deps.sh
# DESCRIPTION: Install dependencies required before running ai-runner scripts.
# USAGE: ./setup-deps.sh
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
load_script_helpers logging os deps

is_wsl() {
    grep -qi "microsoft" /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]
}

install_runner_dependencies() {
    if is_wsl; then
        print_info "WSL2 detected: installing common dependencies; Ollama CLI is expected on Windows host."
        install_dependencies dialog curl jq python3 python3-pip nodejs git
    else
        install_dependencies_ai_runner
    fi
}

ensure_python_deps() {
    if ! command -v python3 >/dev/null 2>&1; then
        print_error "python3 not found; install it and try again."
        return 1
    fi
    if ! python3 -m pip --version >/dev/null 2>&1; then
        print_error "pip not available for python3. Run ./run -i or install python3-pip."
        return 1
    fi
    python3 - <<'PY'
try:
    import bs4  # noqa: F401
    import requests  # noqa: F401
except Exception:
    raise SystemExit(1)
PY
    if [[ $? -ne 0 ]]; then
        print_info "Installing Python deps for model index (beautifulsoup4, requests)..."
        python3 -m pip install --user --upgrade beautifulsoup4 requests
    else
        print_info "Python deps for model index already installed."
    fi
}

install_runner_dependencies
ensure_python_deps
print_success "Dependencies installed."
