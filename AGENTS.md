# AGENTS.md

This file provides guidance to agents when working with code in this repository.

Stack: PowerShell 5.1/7+ and Bash scripts plus a single offline `index.html`. There is no package manager, linter, formatter or automated test suite. Validate with the commands below.

## Commands

Run from the repo root. There is no unit-test runner, so the "single test" is a dry-run of one script or one live Codex prompt.

- Dry-run setup: `powershell -ExecutionPolicy Bypass -File .\setup-codex-ica.ps1 -DryRun` / `bash ./setup-codex-ica.sh --dry-run`
- Dry-run uninstall: `powershell -ExecutionPolicy Bypass -File .\uninstall-codex-ica.ps1 -DryRun` / `bash ./uninstall-codex-ica.sh --dry-run`
- Dry-run codex-security wrapper: `.\codex-security-ica.ps1 -DryRun`. It is not a completed scan.
- PowerShell syntax check (run in PowerShell, repeat for each `.ps1`): `$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\setup-codex-ica.ps1).Path,[ref]$null,[ref]$e); $e.Count`. The result must be `0`.
- Bash syntax check: `bash -n ./setup-codex-ica.sh` (also `./uninstall-codex-ica.sh`)
- Catalog JSON check: `python -m json.tool .\ica-models.json`
- Live single prompt: `cd "$HOME\codex-ica-test"; codex exec "Say hello in one sentence. Do not create or modify any files."`

## Code style

- No formatter config exists, so match the surrounding file. The scripts use banner/section helpers (e.g. `Write-HeaderBox`) and print a version banner at startup.
- Version `2.3.0` is hard-coded in many places: script header comment, startup banner, `index.html` badge, `README.md`, `plan.md` and `RELEASE_NOTES.md`. Bump all of them together and add a `RELEASE_NOTES.md` entry.
- Flag naming: PowerShell uses `-PascalCase` switches. Bash uses `--kebab-case` with the same meaning. Keep them in sync (see Parity below).
- Destructive or confirm prompts default to No (`[y/N]`). `-Yes`/`--yes` and `-NonInteractive` must not enable optional installs (codex-security, ChatGPT Desktop).

## Critical gotchas

- **No UTF-8 BOM**: `[System.Text.Encoding]::UTF8` and `Out-File`/`Set-Content -Encoding utf8` emit a BOM on Windows PowerShell 5.1, and the Rust Codex parser then fails with `expected value at line 1 column 1`. Write files with `[System.IO.File]::WriteAllText($p, $txt, (New-Object System.Text.UTF8Encoding($false)))`. This applies to `config.toml`, `ica-models.json` and `codex-security.yaml`. Use LF in the YAML.
- **TOML top-level keys**: `model`, `model_provider`, `model_catalog_json` and `model_reasoning_effort` must come before any `[table]` header in `~/.codex/config.toml`. Otherwise they attach to that table and Codex falls back to `provider: openai`.
- **TOML Windows paths**: `model_catalog_json` needs doubled backslashes (`C:\\Users\\<user>\\.codex\\model-catalog\\ica-models.json`).
- **Merge, don't overwrite `config.toml`**: keep `[plugins]`, `[marketplaces]`, `[mcp_servers]` and `[shell_environment_policy]`. Strip conflicting top-level keys and stale `[model_providers.ica]` before prepending the new block.
- **Provider**: `[model_providers.ica]` uses `wire_api = "responses"`, `env_key = "ICA_API_KEY"` and base URL `https://api.servicesessentials.ibm.com/v1`. Every model slug in `config.toml` must exist in `ica-models.json` `"models"`.
- **Secrets**: Never pass `ICA_API_KEY` as an argument or commit it. Prompt with `Read-Host -AsSecureString` on Windows and `read -s` on macOS/Linux. Restrict any `.env` or `.env.bak.*` to the owner (`icacls $p /inheritance:r /grant:r "${env:USERNAME}:F"` or `chmod 600`). Backups use `*.bak.yyyyMMdd_HHmmss`.
- **Daemons**: After changing `ICA_API_KEY`, set the User env var (`[Environment]::SetEnvironmentVariable('ICA_API_KEY',$k,'User')`) and run `Stop-Process -Name codex,node_repl -Force`. A running Codex does not pick up the new value.
- **Dry-run is mandatory**: Every mutating operation must have a non-writing preview path.

## Parity and duplicated content

- `setup-codex-ica.ps1` (`-DryRun -Yes -AutoBackup -Overwrite -SkipKeyPrompt -NonInteractive`) and `setup-codex-ica.sh` (`--dry-run --yes --auto-backup --overwrite --skip-key-prompt`) must behave identically. That includes the codex-security step and the numbering of "Next Steps". The same applies to the `uninstall-codex-ica.{ps1,sh}` pair (`-DryRun -Yes -KeepConfig -KeepApiKey -NonInteractive` / `--dry-run --yes --keep-config --keep-api-key`).
- `index.html` repeats two callouts in three tabs: Fast-Track (`tab-auto`), Step 1 (`tab-prereqs`) and Step 4 (`tab-clients`). They are the "IBM Enterprise Workstation Requirement (PC@IBM / Mac@IBM)" banner, the "Existing Configuration Info" banner and the "ChatGPT Desktop App is not installed by the automated setup" banner. Keep the three copies of each identical. The Existing Configuration claims must match script behavior: `config.toml` is merged, the `.env` key can be kept, and `ica-models.json` is rewritten (backup/skip offered).
- `index.html` must stay zero-dependency (no CDN, fonts or external scripts) so it works offline on the IBM intranet. Progress is computed from all `.step-check` checkboxes (`check-prereqs`, `check-portal`, `check-manual`, `check-clients`, `check-testing`).
- ChatGPT Desktop is manual-only (needs admin). `-InstallChatGPT` / `--install-chatgpt` are deprecated no-ops that print the same warning. The desktop app shares `~/.codex/config.toml`, so don't mix a personal ChatGPT account with the work profile.

## Codex Security (optional, opt-in)

- `codex-security` has its own Codex home and ignores `~/.codex/config.toml`, so a plain scan falls back to OpenAI web login. ICA is selected only through a project config (`-c FILE` or `CODEX_SECURITY_PROJECT_CONFIG`, never auto-discovered) or `--codex model_providers.ica.*` overrides. In Windows PowerShell 5.1 the TOML values need `\"` escaping.
- Setup writes `~/.codex/codex-security.yaml` (no BOM, no credentials, `auth: api-key`, `env_key: ICA_API_KEY`). It is selected through the `CODEX_SECURITY_PROJECT_CONFIG` User env var on Windows, or a line in `~/.codex/.env` (backup + `chmod 600` first) on macOS/Linux. If it already points elsewhere, show the conflict and ask (default keep). Never replace it silently.
- Installing `@openai/codex-security` needs an explicit Yes (default No). Node must be `^22.13 || ^24 || ^26` and is never upgraded automatically.
- `codex-security-ica.ps1` prefers `~/.codex/codex-security.yaml` (`-ConfigPath`) and falls back to the overrides. Never set `CODEX_SECURITY_STATE_DIR`, and never copy the ICA key into `OPENAI_API_KEY` (it would be sent to OpenAI).
- Auth success is not scan success: on native Windows the sandbox startup failure is a separate, unresolved problem (likely the Codex/ChatGPT desktop app owning the machine-wide sandbox service). A scan completed from WSL2 (single machine); see README "Scanning from WSL". The YAML schema was tested only against codex-security v0.10.0.
- **WSL detection is bash-only (exception to parity)**: `setup-codex-ica.sh` detects WSL and warns when `node`/`npm`/`codex`/`codex-security` resolve to `/mnt/<drive>/` Windows copies. It is warn-only, has no `.ps1` counterpart, and must not change prerequisite or install behavior.
