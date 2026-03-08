#!/usr/bin/env bash
# Deprecated compatibility shim.
# Runtime helpers moved to script-helpers/lib/ollama.sh.

if ! declare -F ollama_runtime_type >/dev/null 2>&1; then
    helper_load_ok=false
    if declare -F load_script_helpers >/dev/null 2>&1; then
        if load_script_helpers ollama >/dev/null 2>&1; then
            helper_load_ok=true
        fi
    elif declare -F shlib_import >/dev/null 2>&1; then
        if shlib_import ollama >/dev/null 2>&1; then
            helper_load_ok=true
        fi
    else
        echo "ERROR: ollama runtime helpers not loaded. Source scripts/include.sh first." >&2
        if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
            return 1
        fi
        exit 1
    fi

    if [[ "$helper_load_ok" != "true" ]] && ! declare -F ollama_runtime_type >/dev/null 2>&1; then
        echo "ERROR: failed to load Ollama runtime helpers (helper import failed)." >&2
        if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
            return 1
        fi
        exit 1
    fi
fi

if ! declare -F ollama_runtime_type >/dev/null 2>&1; then
    echo "ERROR: failed to load Ollama runtime helpers (ollama_runtime_type is undefined)." >&2
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
        return 1
    fi
    exit 1
fi
