# CHANGELOG

## [0.1.5] - 2026-08-21
- Fix: point `scripts/script-helpers` at the published `0.22.0` tag. Tags `0.1.3` and `0.1.4` recorded commit `c11b42a`, which does not exist in `script-helpers` and is unknown to GitHub, so `git clone --recurse-submodules` failed for anyone installing from a release: `upload-pack: not our ref c11b42a`. The commit was never merged into any surviving ref, so there is nothing to restore; the pin now tracks a published tag rather than whatever the working tree happened to hold.
- CI: check out submodules on every pull request. Nothing in CI touched them, which is why a pin that no consumer could fetch stayed in place from April to August.

## [0.1.4] - 2026-05-14
- Fix: restore model selectors in `./run` and `./get` by preventing `.env` values from clobbering CLI selection state before the dialog flow starts.
- Fix: make `./get` prompt for model, size, destination, and confirmation before downloading, while showing a meaningful archive label instead of a temporary filename in the progress dialog.
- Fix: render selector dialogs through `/dev/tty` so interactive `dialog` menus remain visible when command stdout is captured or wrapped.
- Fix: support explicit long options in `./get` (`--model`, `--url`, `--dir`, `--runtime`, `--debug`, `--verbose`) without colliding with `-d <dir>`.
- Fix: make `./get` download real Ollama registry bundles (`manifest.json` plus blobs) directly, so official models can still be saved to a chosen directory even when `ollama export` is unavailable in the installed CLI.
- CI: harden auto-tagging workflow permissions by explicitly requesting `pull-requests: read` while delegating to the reusable workflow.
- Tooling: ignore local downloaded model artifacts under `models/`.
- Tooling: update `scripts/script-helpers` to include stabilized Ollama dialog selector behavior for TTY sessions.

## [0.1.3] - 2026-04-28
- Feature: add Ollama registry bundle download support in `./get`, including manifest/blob staging and digest verification.
- Fix: restore interactive model selection in `./run` and `./get` after the selector flow regressed.
- Fix: make `./get` fallback handling explicit when export is unavailable, including clearer success and failure messaging.
- Fix: harden non-interactive prompt/model guards so scripted runs fail clearly instead of opening dialogs.
- Fix: make registry bundle staging, finalization, and temporary-file handling safer across failure paths.
- CI: tighten release tag detection and switch to the shared ci-helpers auto-tag workflow.
- Tooling: add portable registry bundle tests and shell probes for the download flow.

## [0.1.2] - 2026-03-23
- Fix: restore fully TUI-based model selection in `./run` and `./get` with no free-form model-name entry.
- Fix: default interactive model browsing to official un-namespaced Ollama library models, sorted alphabetically, to avoid community duplicates in the main selector.
- Fix: keep interactive selection loops in `./run` and `./get` so cancelling the size dialog returns to model selection instead of silently reusing a prior size.
- Fix: show a loading indicator before opening the model selector and reuse a parsed model-menu cache for up to 30 minutes to speed up reopen flows.
- Fix: route Ollama pull progress through a dialog gauge and prevent helper status output from corrupting `.env` values.

## [0.1.1] - 2026-03-16
- Feature: add an `About` dialog to `./run` with project links plus GitHub and LinkedIn profile links.
- Fix: keep `./run -i` bootstrap flow install-first so fresh machines do not require `dialog` before dependency setup.
- Fix: clarify `./get` fallback success messages so the requested output directory and the actual Ollama runtime model-store path are reported separately when export is unavailable.
- Tooling: add `tests/test.sh` as the documented shell smoke-test entrypoint.
- Docs: clarify that `./scripts/lint.sh` requires ShellCheck to be installed locally.

## 2026-02-12
- Feature: add runtime abstraction for Ollama (`local` or `docker`) using shared helpers from `scripts/script-helpers/lib/ollama.sh`.
- Feature: add Docker-backed Ollama flow with managed container startup, mounted model data dir, and runtime-aware pull/export/ps in `run/get/prompt`.
- Feature: make `./get` TUI-first in interactive mode and add selector flow for indexed models or manual entry of any model/tag.
- Fix: prevent `./get` from hard-failing on missing tar URLs (e.g., HTTP 404) when runtime fallback pull can proceed.
- Fix: treat pull-without-export support as successful fallback and report cache location instead of warning as failure.
- Refactor: keep `scripts/ollama-runtime.sh` as a compatibility shim while loading runtime APIs from `script-helpers`.
- Refactor: remove duplicated local helpers in scripts (`ollama_model_ref`, `is_wsl`) and reuse shared functions from `script-helpers`.
- Config: introduce `ollama_scheme`, `ollama_host`, and `ollama_port`; auto-generate/sync `ollama_url` from these fields in scripts.
- Config: add shared model-store controls (`ollama_shared_model_store`, `ollama_local_models_dir`) to reuse pulled models across local and Docker runtimes.
- Docs: update README and command docs for runtime selection, model sharing, and new env structure.

## [0.1.0] - 2026-02-04
- Feature: release the improved TUI setup and run flow from PR #10.
- Tooling: update `scripts/setup-deps.sh`, `example.sh`, CI helper wiring, and the `scripts/script-helpers` submodule.
- Fix: gate dependency setup and pin CI helper usage for the release workflow.

## 2025-12-30
- Refactor: move root scripts into `scripts/` and keep entrypoint symlinks (`run`, `get`, `prompt`) at repo root.
- Tooling: make `scripts/lint.sh` resilient when `scripts/script-helpers` is missing (CI-safe fallback logging).
- CI: switch ShellCheck workflow to `nikolareljin/ci-helpers` reusable workflow.
- Docs: update README/AGENTS to prefer symlinked commands and reflect new layout.
- Docs: document `./example.sh` (Next.js demo bootstrap) in README and commands list.
- Tooling: `./example.sh` now scaffolds the Vercel AI Ollama example and writes `example/.env.local` from `.env`.

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
