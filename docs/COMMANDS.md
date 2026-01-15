# Commands

This project ships root-level command symlinks for the main scripts:
`./run`, `./prompt`, `./get`, `./update`, `./example.sh`, and `./scripts/lint.sh`.

## ./run

Select a model/size, run it, and prompt the local Ollama API.

Usage:

```sh
./run [-h] [-i] [-m <model>] [-p <prompt>]
```

Options:
- `-i`: install dependencies and Ollama CLI (if needed).
- `-m <model>`: preselect a model.
- `-p <prompt>`: send a prompt immediately (skips prompt dialog).

Examples:

```sh
./run
./run -i
./run -m llama3 -p "Hello"
```

## ./prompt

Prompt the configured model using the local API.

Usage:

```sh
./prompt [-h] [-p "<prompt>"]
```

Options:
- `-p "<prompt>"`: send a prompt immediately (skips dialog).

Examples:

```sh
./prompt
./prompt -p "Why is the sky blue?"
```

## ./get

Download a model archive for offline use or analysis.

Usage:

```sh
./get [-h] [-m <model>] [-u <url>] [-d <dir>]
```

Options:
- `-m <model>`: model name (defaults to current selection or dialog).
- `-u <url>`: direct tar URL (if available).
- `-d <dir>`: destination directory (created if missing).

Examples:

```sh
./get -m llama3 -d ./models
./get -u https://ollama.com/models/llama3.tar.gz -d ./models/llama3
```

Notes:
- If run without flags, it opens a dialog to select a model and size.
- If a direct tar URL is unavailable, it falls back to `ollama pull` and then
  attempts to export to a local file when supported.

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
