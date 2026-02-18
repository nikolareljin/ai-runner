#!/usr/bin/env bash
# Deprecated compatibility shim.
# Runtime helpers moved to script-helpers/lib/ollama.sh.

if ! declare -F ollama_runtime_type >/dev/null 2>&1; then
    if declare -F load_script_helpers >/dev/null 2>&1; then
        load_script_helpers ollama >/dev/null
    elif declare -F shlib_import >/dev/null 2>&1; then
        shlib_import ollama >/dev/null
    else
        echo "ERROR: ollama runtime helpers not loaded. Source scripts/include.sh first." >&2
        return 1
    fi
fi
