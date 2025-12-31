# Installation Guide

This project runs on macOS, Linux, and WSL2 (Windows via WSL2). On WSL2, install
and run the Windows Ollama app; scripts connect to `http://localhost:11434`.

## Quick Start

```sh
./update
./run -i
```

- `./update` initializes/updates the `scripts/script-helpers` submodule.
- `./run -i` installs common dependencies (OS-specific) and can prepare the
  model list.

## Required Dependencies

- Ollama running locally:
  - macOS/Linux: install the Ollama app/CLI.
  - WSL2: install and run the Windows Ollama app.
- CLI tools used by scripts: `curl`, `jq`, `dialog`.
- Git (required for submodules).

## Optional (for tests/examples)

- Python 3
- Node.js (Node 20 recommended)

## Install Links

- Ollama: https://ollama.com/download
- jq: https://jqlang.github.io/jq/download/
- dialog: https://invisible-island.net/dialog/dialog.html

## Notes

- If a script prints "script-helpers dependency not found", run `./update`.
- You can also install dependencies manually, but `./run -i` is the recommended
  path on supported systems.
