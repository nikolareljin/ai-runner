# Repository Guidelines

## Supported OS
- macOS, Linux, and WSL2 (Windows via WSL2). On WSL2, install and run the Windows Ollama app; scripts connect to `http://localhost:11434` from WSL.

## Project Structure & Module Organization
- Core scripts: `run.sh` (install, choose model, run + prompt), `prompt.sh` (prompt an existing model), `get.sh` (download a model tar).
- Symlinks: `run` → `run.sh`, `get` → `get.sh` (both forms work).
- Shared helpers: `scripts/script-helpers` submodule (dialog sizing, installers, logging, formatting); `include.sh` is a legacy shim.
- Config: `.env` (gitignored), seed from `.env.example.txt`.
- Model index: `ollama-get-models/` (auto-cloned by `./run -i`) produces `./ollama-get-models/code/ollama_models.json`.
- Tests: `tests/` contains shell, Python, and JS examples.
- Example app: `example/` (Next.js demo, optional for core scripts).

## Build, Test, and Development Commands
- Setup dependencies and model list: `./run -i`
- Run model + prompt: `./run -m llama3 -p "Hello"`
- Prompt existing model: `./prompt -p "Why is the sky blue?"` (requires `.env` with `model` and `size`)
- Download model to folder: `./get.sh -m llama3 -d ./models` (or `./get ...` alias)
- Sanity checks: `curl http://localhost:11434/api/tags`, `curl http://localhost:11434/api/generate ...`
- Run tests/examples:
  - `bash tests/test.sh`
  - `python3 tests/test-chat-python.py`
  - `node tests/test-chat-javascript.js`
  - `bash tests/test-chat-completions.sh`
- Lint shell scripts: `./scripts/lint.sh` (set `STRICT=1` to fail on warnings). CI enforces strict ShellCheck on PRs.

## Coding Style & Naming Conventions
- Language: Bash. Use 4-space indentation and double quotes.
- Functions: lower_snake_case. Prefer helpers (`print_info`, `print_error`, `print_success`) over raw `echo`.
- Constants uppercase (e.g., `DIALOG_WIDTH`). Script files: `kebab-case.sh`. Tests: `tests/test-*.{sh,py,js}`.
- Use `jq` for JSON parsing; keep prompts sanitized before sending.

## Testing Guidelines
- Ensure Ollama is running and `.env` is set (run `./run` once to select `model` and `size`).
- Keep tests fast and self-contained; no coverage target.
- Add new tests under `tests/` following existing naming and minimal-deps approach.
- Python 3 and Node 20 are expected; `./run -i` installs/upgrades common tooling.

## Commit & Pull Request Guidelines
- Follow Conventional Commits (e.g., `feat:`, `fix:`, `chore:`) as in Git history.
- PRs include: summary, rationale, repro steps/commands, and sample output or screenshots (dialog responses) when relevant.
- Update README/AGENTS when flags, prompts, or flows change.
- Do not commit secrets or large artifacts (.env, model files). `.env` is already gitignored.

## Security & Configuration Tips
- Copy `.env.example.txt` to `.env` and adjust `model`, `size`, and endpoints.
- Validate inputs and handle empty responses; prefer `jq` for robust parsing.
