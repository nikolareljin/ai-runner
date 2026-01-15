# CHANGELOG

## 2025-12-30
- Refactor: move root scripts into `scripts/` and keep entrypoint symlinks (`run`, `get`, `prompt`) at repo root.
- Tooling: make `scripts/lint.sh` resilient when `scripts/script-helpers` is missing (CI-safe fallback logging).
- CI: switch ShellCheck workflow to `nikolareljin/ci-helpers` reusable workflow.
- Docs: update README/AGENTS to prefer symlinked commands and reflect new layout.
- Docs: document `./example.sh` (Next.js demo bootstrap) in README and commands list.

## 2025-10-29
- Docs: add AGENTS.md with repo-specific contributor guidelines.
- CI: introduce ShellCheck workflow and enforce strict checks on PRs.
- Tooling: add `scripts/lint.sh` and document linting in AGENTS.md.
- Templates: add `.github/pull_request_template.md` to standardize PRs.
- Docs: update README with `get.sh` usage, help, and `./get` alias.
- Tooling: add `get` → `get.sh` symlink and document the alias.
- OS Support: add WSL2 detection and support in `include.sh` (clipboard via `clip.exe`, dependency installs), skip Ollama install inside WSL2, and update `run.sh` to gracefully skip `ollama` CLI when unavailable.
- Docs: add Supported OS sections to README and AGENTS.md (macOS, Linux, WSL2).
- Feature: make `get.sh` interactive (like `run.sh`) when no flags are provided: select model and size from index, derive download URL, and extract to `./models/<model>[-<size>]`.
- Enhancement: validate downloads, detect non-gzip responses, and fallback to `ollama pull` + `ollama export` when available; document behavior in README.

## 2025-12-29
- Tooling: add `scripts/script-helpers` submodule and standard loader wiring in scripts.
- Refactor: migrate bash scripts to `script-helpers` modules (logging, dialog, env, json, ollama, deps).
- Docs: update script headers to match library help conventions and document submodule init in README.
- Compatibility: replace `include.sh` with a legacy shim and adjust WSL clipboard handling in scripts.

## 2025-10-01
- Merge PR #5 to update model/run flow.
- Refine `include.sh` dependency helpers.

## 2025-07-03
- Standardize logging in `install_dependencies()` using `print_*` helpers.

## 2025-07-02
- Fix dependency installation logic in `include.sh`.

## 2025-07-01
- Improve `prompt.sh` behavior and help info.

## 2025-06-30
- Enhance `prompt.sh` (multi-line input, sanitization) and `run.sh` UX.
- Update `include.sh` utilities and color helpers; adjust CHANGELOG.
- Add `tests/test-chat-completions.sh` and refine messages.

## 2025-06-09
- Clean up color-print helpers and usage.

## 2025-05-19
- Add test scripts for chat endpoints (Bash, Python, Node).

## 2025-05-11
- Update README (usage, endpoints); add helper info for `get.sh`.

## 2025-05-09
- Improve help display in `include.sh`; add header-driven `display_help`.

## 2025-05-08
- Introduce shared helper library; copy responses to clipboard.
- Add README curl examples; general cleanup; merge PR #4.

## 2025-05-07
- Add `./prompt` script; update README and CHANGELOG.
- Update `run.sh`: model size selection, sort models, improve flow; merges PRs #2/#3.

## 2025-05-06
- Add `size` to `.env` template and selection in `run.sh`.

## 2025-05-05
- Add `./run` symlink; update models configuration.

## 2025-02-06
- Update and fix available model lists; chmod tweaks; WIP run/get improvements.

## 2025-02-03
- Update setup and install scripts; merge PR #1.

## 2025-01-23
- Bootstrap repo: add `.gitignore`, README, and setup script.

## 2024-12-07
- Initialize master branch and CHANGELOG.

## Update helper methods, display of help, sanitization, multi-line entry
- `tests/test-chat-python.py` -	Added a Python test for chat completion.
- `tests/test-chat-javascript.js` -	Added a JavaScript test for chat completion.
- `tests/test-chat-completions.sh	Added a shell test for chat completions (note potential JSON formatting issue).
- `run.sh` - Enhanced the run script by incorporating a help flag and updating comments.
- `prompt.sh` -	Updated the prompt script for multi-line input handling and sanitation.
- `include.sh` -	Refactored dependency installation, added Node.js upgrade logic, and introduced color functions.
- `get.sh` -	Updated the get script with help functionality and argument parsing.
README.md	Extended documentation with new endpoints and usage instructions.

## Add shared library for functions
- Group shared functions into ./include.sh file, which will be used by the scripts
- Update installation of dependencies. Include clipboard helper to preserve the responses.

## Add ./prompt script for prompting
- add script ./prompt which allows communication with the running ollama model with curl requests

## Dynamic pull of models
- Pull all ollama available models and store them into JSON file (using git repo Python dependency: `webfarmer/ollama-get-models`)
- select model and size to run
- store values into `.env` file and update on each run

## Update models and run script
- Update models list for running small models available on ollama
- update run script and dialog options
  - add ./run symlink for simplicity
- add .env.example.txt file to allow configurable running in the future using .env file

## Initial release
- Setup scripts to install Ollama
- Run example llama3 prompt
