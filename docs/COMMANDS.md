# Commands

This project ships root-level command symlinks for the main scripts:
`./run`, `./prompt`, `./get`, `./update`, `./example.sh`, and `./scripts/lint.sh`.

## ./run

Select a model/size, run it, and prompt the local Ollama API.

Usage:

```sh
./run [-h] [-i] [-m <model>] [-p <prompt>] [-r <runtime>]
```

Options:
- `-i`: install dependencies and Ollama CLI (if needed).
- `-m <model>`: preselect a model.
- `-p <prompt>`: send a prompt immediately (skips prompt dialog).
- `-r <runtime>`: runtime to use (`local` or `docker`).

Examples:

```sh
./run
./run -i
./run -m llama3 -p "Hello"
./run -r docker -m llama3 -p "Hello from containerized Ollama"
```

## ./prompt

Prompt the configured model using the local API.

Usage:

```sh
./prompt [-h] [-p "<prompt>"] [-r <runtime>]
```

Options:
- `-p "<prompt>"`: send a prompt immediately (skips dialog).
- `-r <runtime>`: runtime to use (`local` or `docker`).

Examples:

```sh
./prompt
./prompt -p "Why is the sky blue?"
./prompt -r docker -p "Explain gradient descent."
```

## ./get

Download a model archive for offline use or analysis.

Usage:

```sh
./get [-h] [-m <model>] [-u <url>] [-d <dir>] [-r <runtime>]
```

Options:
- `-m <model>`: model name (defaults to current selection or dialog).
- `-u <url>`: direct tar URL (if available).
- `-d <dir>`: destination directory (created if missing).
- `-r <runtime>`: runtime for fallback pull/export (`local` or `docker`).

Examples:

```sh
./get -m llama3 -d ./models
./get -u https://ollama.com/models/llama3.tar.gz -d ./models/llama3
./get -m llama3 -r docker
```

Notes:
- If run without flags, it opens a dialog to select from indexed models or enter any model manually.
- If a direct tar URL is unavailable, it falls back to runtime pull (`local` CLI or Docker container) and then attempts to export to a local file when supported.

## ./update

Initialize or update git submodules (including `scripts/script-helpers`).

Usage:

```sh
./update [-h]
```

## ./example.sh

Bootstrap the Next.js demo app from the Vercel AI example.

Usage:

```sh
./example.sh [-h]
```

Notes:
- Generates the demo in `./example/`.
- Requires Node.js and npm.
- Reads `.env` (creates from `.env.example` if needed) and writes `example/.env.local`.
- Uses `model`, `size`, `ollama_host`, `ollama_port`, and `ollama_url` from `.env` to configure the Ollama base URL and model.
- `ollama_url` is generated from `ollama_scheme` + `ollama_host` + `ollama_port`; legacy `website` is only a fallback.
- You may want to remove `example/node_modules` from git (see `.gitignore`).

## ./scripts/lint.sh

Run ShellCheck on tracked shell scripts.

Usage:

```sh
./scripts/lint.sh [-h]
```

Environment:
- `STRICT=1` to fail on warnings.

Example:

```sh
STRICT=1 ./scripts/lint.sh
```
