# AI Runner

Runner for AI models in the local system.
Allows to quickly run models available on ollama website with a single command.

Models available at: https://ollama.com/search

## Supported OS
- macOS
- Linux
- WSL2 (Windows via WSL2). Install and run the Windows Ollama app; this project runs inside WSL2 and connects to `http://localhost:11434`.


# Run the model and install

Run the command:

`./run [-i] [-m <model>] [-p]`

Parameters: 

- `-i`          : install dependencies and ollama
- `-m <model>`  : define the model to use
- `-p <prompt>` : run the prompt command right away

Example:

```sh
./run
```

# Run the prompt in existing model

If you already set up the model, size and have run the steps under `./run`, you can run the prompt directly, using the Curl request and see the results in the dialog:

```
./prompt
```

![image](https://github.com/user-attachments/assets/eb3512a6-c13f-467e-8fc4-04d406d97ec9)


# Only download the models

Use `./get.sh` to download a model archive (tar.gz) to a local folder for offline use or analysis. This does not install the model into Ollama — use `./run` (or `ollama pull`) to run it. Alias: `./get` is a symlink to `./get.sh`; both forms work.

Examples:

```sh
# Download a known model by name to ./models
./get.sh -m llama3 -d ./models
# or using the alias:
./get -m llama3 -d ./models

# Or provide a direct tar URL (if available)
./get.sh -u https://ollama.com/models/llama3.tar.gz -d ./models/llama3
```

Notes:
- The script creates the destination directory if it does not exist and extracts the archive there.
- To run a model with Ollama, prefer `./run` to select and pull a model (internally uses `ollama pull`), e.g.:

```sh
./run -m llama3 -p "Hello"
```

- Some tar URLs may not be publicly available for all models; in such cases use `./run` or `ollama pull <model>:<tag>`.
- Optional: you can track a local path in `.env` via `model_path=./models/<name>` for your own workflows (not required by `./run`).

## get.sh help

View usage and options:

```sh
./get.sh -h
# or
./get -h
```

Summary:
- Usage: `./get.sh [-m <model>] [-u <url>] [-d <dir>]`
- Options:
  - `-m <model>`: model name (default: `llama3`)
  - `-u <url>`: direct tar URL (if available)
  - `-d <dir>`: destination directory (created if missing)
Example: `./get.sh -m llama3 -d ./models`

# Run prompts as CURL

You can run prompts against the running model via curl commands:

Example:

```
curl -X POST http://localhost:11434/api/generate -d "{\"model\": \"llama3\",  \"prompt\":\"Tell me about the meaning of life.\", \"stream\": false}"
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
