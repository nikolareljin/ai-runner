# AI Runner

Runner for AI models in the local system.
Allows to quickly run models available on ollama website with a single command.

Models available at: https://ollama.com/search

## Supported OS
- macOS
- Linux
- WSL2 (Windows via WSL2). Install and run the Windows Ollama app; this project runs inside WSL2 and connects to `http://localhost:11434`.

## Runtime modes
- `local`: uses locally installed `ollama` CLI and local Ollama API.
- `docker`: uses an Ollama Docker container and mounted data dir for models.

Set in `.env`:

```sh
ollama_scheme=http
ollama_host=localhost
ollama_port=11434
ollama_runtime=local
ollama_url=http://localhost:11434
ollama_docker_container=ai-runner-ollama
ollama_docker_image=ollama/ollama:latest
ollama_data_dir=./models/ollama-data
ollama_shared_model_store=1
ollama_local_models_dir=./models/ollama-data/models
```

You can override per command with `-r local` or `-r docker`.
`ollama_url` is auto-generated/updated by scripts from `ollama_scheme`, `ollama_host`, and `ollama_port`.
Legacy `website` is optional and only used as a backward-compatibility fallback.
When `ollama_shared_model_store=1`, local pull/export uses the same model store path as Docker mount, so one pulled model can be reused across both runtimes.

## Dependencies
Initialize or update the script helpers submodule before running scripts:

```sh
./update
```

If you see a "script-helpers dependency not found" message, run `./update` first.
See [docs/INSTALL.md](docs/INSTALL.md) for the rest of the installation steps.

Core scripts live in `scripts/`; use the root symlinks where possible.

Install core dependencies before running:

```sh
./setup-deps
```


# Example app (Next.js)

To scaffold the demo app from the Vercel AI example:

```sh
./example.sh
```

Notes:
- This creates/overwrites `./example/`.
- Requires Node.js and npm.
- `example/node_modules` should remain untracked (see `.gitignore`).
- The script reads `.env` (creates from `.env.example` if needed) and writes `example/.env.local`.
- Ollama settings are taken from `model`, `size`, `ollama_host`, `ollama_port`, and `ollama_url` in `.env`.

# Run the model and install

Run the command:

`./run [-i] [-m <model>] [-p] [-r <runtime>]`

Parameters: 

- `-i`          : install dependencies and ollama
- `-m <model>`  : define the model to use
- `-p <prompt>` : run the prompt command right away
- `-r <runtime>`: `local` or `docker`

Example:

```sh
./run
./run -r docker -m llama3 -p "Hello"
```

If NO MODEL was selected, a selector will be displayed - so you can pick one that is available on Ollama:

<img width="1121" height="566" alt="image" src="https://github.com/user-attachments/assets/661c89a0-a6cb-46e7-8b8c-fdf89c95d95e" />


# Run the prompt in existing model

If you already set up the model, size and have run the steps under `./run`, you can run the prompt directly, using the Curl request and see the results in the dialog:

```
./prompt
./prompt -r docker -p "Summarize this project"
```

![image](https://github.com/user-attachments/assets/eb3512a6-c13f-467e-8fc4-04d406d97ec9)


# Only download the models

Use `./get` to download a model archive (tar.gz) to a local folder for offline use or analysis.
If direct tar download is unavailable, it falls back to model pull via your selected runtime (`local` or `docker`).

Examples:

```sh
# Download a known model by name to ./models
./get -m llama3 -d ./models
./get -m llama3 -r docker

# Or provide a direct tar URL (if available)
./get -u https://ollama.com/models/llama3.tar.gz -d ./models/llama3
```

Notes:
- The script creates the destination directory if it does not exist and extracts the archive there.
- If you run without flags, it opens a dialog to choose either:
  - indexed selection (model + size from model index), or
  - manual entry (any Ollama model name/tag).
- Default destination remains `./models/<model>-<size>`.
- To run a model with Ollama, prefer `./run` to select and pull a model (internally uses `ollama pull`), e.g.:

```sh
./run -m llama3 -p "Hello"
```

- Some tar URLs may not be publicly available for all models; in such cases use `./run` or `ollama pull <model>:<tag>`.
- If a direct tar URL is unavailable (non-gzip response), the script falls back to runtime pull (`local` CLI or Docker container) and, when supported, exports an `.ollama` file in your destination.
- In Docker mode, pulled models are stored in `ollama_data_dir` (mounted into the container at `/root/.ollama`) so they are reusable across runs.
- Optional: you can track a local path in `.env` via `model_path=./models/<name>` for your own workflows (not required by `./run`).

## get.sh help

View usage and options:

```sh
./get -h
```

Summary:
- Usage: `./get [-m <model>] [-u <url>] [-d <dir>] [-r <runtime>]`
- Options:
  - `-m <model>`: model name (default: `llama3`)
  - `-u <url>`: direct tar URL (if available)
  - `-d <dir>`: destination directory (created if missing)
  - `-r <runtime>`: runtime for fallback pull/export (`local` or `docker`)
Example: `./get -m llama3 -d ./models`

# Run prompts as CURL

You can run prompts against the running model via curl commands:

Example:

```
curl -X POST "${OLLAMA_URL:-http://localhost:11434}/api/generate" -d "{\"model\": \"llama3\",  \"prompt\":\"Tell me about the meaning of life.\", \"stream\": false}"
``` 

# Endpoints

- http://localhost:11434/api/tags
- http://localhost:11434/api/generate


Check parameters of the currently installed model:

First, check what is the installed (and running) model. It should reflect what's in the `.env` file.

Run:

```
source .env
ollama show --modelfile $MODEL
```
