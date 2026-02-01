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

resolve_python_cmd() {
    if command -v python3 >/dev/null 2>&1; then
        echo "python3"
        return 0
    fi
    if command -v python >/dev/null 2>&1 && python - <<'PY'
import sys
raise SystemExit(0 if sys.version_info[0] == 3 else 1)
PY
    then
        echo "python"
        return 0
    fi
    return 1
}

ensure_python_deps() {
    local python_cmd
    python_cmd="$(resolve_python_cmd)" || {
        print_error "python3 not found; install it and try again."
        return 1
    }
    if ! "$python_cmd" -m pip --version >/dev/null 2>&1; then
        print_error "pip not available for python3. Run ./run -i or install python3-pip."
        return 1
    fi
    if "$python_cmd" - <<'PY'
try:
    import bs4  # noqa: F401
    import requests  # noqa: F401
except Exception:
    raise SystemExit(1)
PY
    then
        print_info "Python deps for model index already installed."
    else
        if command -v apt-get >/dev/null 2>&1; then
            print_info "Installing Python deps via apt (python3-bs4, python3-requests)..."
            if ! run_with_optional_sudo true apt-get update; then
                print_warning "apt-get update failed; attempting install with existing package lists."
            fi
            run_with_optional_sudo true apt-get install -y python3-bs4 python3-requests
        else
            print_info "Installing Python deps for model index (beautifulsoup4, requests)..."
            "$python_cmd" -m pip install --user --upgrade beautifulsoup4 requests
        fi
    fi
}

install_runner_dependencies
ensure_python_deps
print_success "Dependencies installed."
