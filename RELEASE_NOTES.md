# Release Notes — IBM ICA + Codex Integration Toolkit

All notable changes, architectural updates, security assessments, and configuration schema migrations for the **IBM ICA (IBM Consulting Advantage) + Codex Integration Toolkit** are documented in this file.

---

## [2.3.0] — 2026-11-17

### 🚀 Features Added
- **GitHub CLI (`gh`) Verification & Automated Install**: Both setup scripts (`setup-codex-ica.ps1` via `winget` `GitHub.cli`, `setup-codex-ica.sh` via `brew install gh`) now verify `gh --version` and offer automated installation if missing.
- **Automated Uninstaller & Cleanup Tools** (`uninstall-codex-ica.ps1`, `uninstall-codex-ica.sh`): Provides safe, automated cleanup for fresh reinstalls with explicit confirmation (`[y/N]`), `-DryRun` preview, daemon recycling, npm package removal, optional `~/.codex` archiving/deletion, and environment variable cleanup.
- **Optional `codex-security` support in both setup scripts** (`setup-codex-ica.ps1`, `setup-codex-ica.sh`): detects `codex-security` and its version, checks Node.js (`^22.13 || ^24 || ^26`), and offers to install `@openai/codex-security`. The prompt **defaults to No**, `-Yes` / `-NonInteractive` / `--yes` do not enable it, and Node.js is never upgraded automatically.
- **ICA project config** `~/.codex/codex-security.yaml` (UTF-8 without BOM, no credentials, `auth: api-key` + `env_key: ICA_API_KEY`). Existing files follow the usual backup / overwrite / skip prompts. Schema tested against **codex-security v0.10.0** only.
- **`CODEX_SECURITY_PROJECT_CONFIG`** selects that file: set as a User environment variable on Windows, and written to `~/.codex/.env` (backed up, `chmod 600`) on macOS/Linux. If it already points elsewhere, the conflict is shown and you are asked; it is never replaced silently (default: keep).
- **`codex-security-ica.ps1`** reuses the project config via the new `-ConfigPath` parameter, keeps `-Path` validation and `-DryRun`, and states that auth selection does not guarantee sandbox startup or scan completion.
- `index.html`: version badge `v2.3.0`, Step 1.1 `gh --version` verification, Step 1.2 download table row, and TAB 6 automated uninstallation / fresh reinstall FAQ.

### ⚠️ Known Limitations
- Selecting ICA for `codex-security` only fixes authentication. A scan can still fail at the Windows sandbox setup stage (`failed to prepare Windows sandbox`); this is a separate, unresolved problem.
- A `-DryRun` of the wrapper previews the selected method only and is not a completed scan.

---

## [2.2.0] — 2026-11-15

### 🔄 Changed
- **ChatGPT Desktop is no longer installed by the setup scripts** (it requires administrator privileges and must be installed manually, where approved by IBM policy). The winget (`OpenAI.ChatGPT`) and `brew install --cask chatgpt` steps were removed from `setup-codex-ica.ps1` and `setup-codex-ica.sh`.
- **Deprecated no-op flags**: `-InstallChatGPT` / `--install-chatgpt` are still accepted so existing automation does not break. They install nothing and print the same deprecation message in both scripts.
- **Informational banner** "ChatGPT Desktop App is not installed by the automated setup" added to the Fast-Track, Step 1 and Step 4 tabs of `index.html`, the README, and the scripts (startup message, Planned Actions preview and Next Steps).
- `index.html` Step 4.2: the `winget` / `brew` commands are kept as manual options and labelled "Requires administrator privileges".

---

## [2.1.0] — 2026-11-14

### 🚀 Features Added & Enhanced
- **Automatic Prerequisite Installation**: `setup-codex-ica.ps1` (winget: `Git.Git`, `OpenJS.NodeJS.LTS`, `Python.Python.3.14`) and `setup-codex-ica.sh` (Homebrew: `git`, `node`, `python`) now offer to install missing Git, Node.js/npm and Python, with confirmation and Dry-Run preview. Windows reloads `PATH` afterwards so Codex CLI installs in the same run. VS Code is never installed by the scripts (use `PC@IBM` / `Mac@IBM`).
- **Script Version Banner**: Both scripts print their version at startup to identify outdated copies.
- **IBM Enterprise Workstation Banner**: Now shown on the Fast-Track and Step 1 tabs of `index.html` (previously Step 4 only).
- **Existing Configuration Info Banner**: New "Prerequisite: install VS Code first — existing Codex configuration is preserved and merged" callout on the Fast-Track, Step 1 and Step 4 tabs of `index.html`, a matching note in `README.md`, and a note line in the scripts' Planned Actions preview (also shown by Dry-Run).

---

## [2.0.0] — 2026-11-14

### Overview
Major release adding automated file backup and overwrite engines, unified branding alignment (*IBM ICA + Codex*), enterprise security hardening (NTFS owner-only ACLs & POSIX `chmod 600`), project-wide rule governance (`AGENTS.md` and `.bob/rules-*/`), and a comprehensive 5-step verification roadmap.

### 🚀 Features Added & Enhanced
- **Auto-Backup & Overwrite Engine**:
  - Implemented timestamped automatic backups (`*.bak.YYYYMMDD_HHMMSS`) for `config.toml`, `.env`, and `ica-models.json`.
  - Added CLI flags: `-AutoBackup` / `--auto-backup`, `-Overwrite` / `--overwrite`, `-DryRun` / `--dry-run`, `-Yes` / `--yes`, `-InstallChatGPT` / `--install-chatgpt`.
  - Enabled true 1-click non-blocking unattended execution when `-AutoBackup` or `-Overwrite` is specified.
- **Branding Alignment**:
  - Standardized project title and interface branding to **IBM ICA (IBM Consulting Advantage) + Codex** across scripts, web guides, documentation, and configuration headers.
- **5-Step Setup & Verification Roadmap**:
  - Restructured the setup lifecycle into 5 distinct, sequential steps (1: Prerequisites, 2: ICA Portal & Key, 3: Configuration, 4: Client Setup, 5: Verification & Testing).
  - Added 1-click `✓ Mark All 5 Steps Done (100%)` button in `index.html` for Fast-Track script users.
  - Added detailed verification sections for Codex CLI, VS Code extension (`OpenAI.chatgpt`), and ChatGPT Desktop app.
  - Added IBM Enterprise Workstation guidance enforcing Visual Studio Code installation via official internal software repositories (**`PC@IBM`** for Windows / **`Mac@IBM`** for macOS).
- **Agent Rules & Governance**:
  - Added root [`AGENTS.md`](AGENTS.md) and mode-specific rules in `.bob/rules-agent/AGENTS.md`, `.bob/rules-ask/AGENTS.md`, and `.bob/rules-plan/AGENTS.md`.
- **Repository Hygiene & `.gitignore`**:
  - Added complete enterprise `.gitignore` protecting `.env`, credentials, backups (`*.bak*`), and system caches.

### 🔒 Security Findings & Vulnerability Fixes
1. **SEC-01 (High — CWE-732 / Credential Exposure)**: Storing API keys in `.env.bak` could leave backup keys world-readable if default file permissions applied.
   - *Fix*: Backups of `.env` now explicitly inherit owner-only permissions via `icacls` on Windows and `chmod 600` on macOS/Linux.
2. **SEC-02 (Medium — CWE-200 / Information Disclosure)**: Interactive API key prompts could expose keys on screen or in shell histories.
   - *Fix*: Integrated `Read-Host -AsSecureString` with marshal zero-free memory cleanup on Windows and `read -s` on POSIX systems.
3. **BUG-01 (Medium — Functional Parser Failure)**: Duplicate catalog block in `setup-codex-ica.sh` referenced obsolete `gpt-5.6-sol-pro` slug.
   - *Fix*: Consolidated catalog writer in `setup-codex-ica.sh` to write the standard 6-model catalog (`gpt-5.6-luna`) matching `ica-models.json`.

### 🗄️ Database Changes & Migrations
- **Database Architecture**: This project is a client-side setup automation and developer toolkit that operates on local filesystem configuration files (`~/.codex/config.toml`, `~/.codex/model-catalog/ica-models.json`, `~/.codex/.env`). It does not utilize a relational or NoSQL database.
- **Schema & Configuration Migrations**:
  - *v1.0.0 &rarr; v2.0.0*: Model catalog upgraded to pure RFC 8259 JSON schema with 6 validated models (`gpt-advantage-assist`, `gpt-5.6-sol`, `gpt-5.6-luna`, `gpt-5.6-terra`, `gpt-5.4`, `gpt-5.1`).
  - *Configuration Format*: Top-level TOML settings enforce `wire_api = "responses"`, `model_provider = "ica"`, and `base_url = "https://api.servicesessentials.ibm.com/v1"`.

---

## [1.2.0] — 2026-11-13

### 🚀 Features Added
- Added Dry-Run / Preview Mode (`-DryRun` / `--dry-run`) displaying full file diffs and action previews before execution.
- Added explicit user approval prompts before every installation, file modification, or background process termination.
- Integrated automated ChatGPT Desktop App installation checks via `winget` (Windows) and `brew` (macOS).

### 🔒 Security & Bug Fixes
- Fixed UTF-8 BOM encoding issue where PowerShell `[System.Text.Encoding]::UTF8` wrote a 3-byte BOM, crashing Codex's Rust JSON parser (`expected value at line 1 column 1`). Resolved by writing pure UTF-8 without BOM via `New-Object System.Text.UTF8Encoding($false)`.
- Fixed background daemon environment variable caching where stale `codex.exe` and `node_repl.exe` processes held old empty environments in memory.

---

## [1.1.0] — 2026-11-13

### 🚀 Features Added
- Created interactive single-page offline web setup assistant ([`index.html`](index.html)) with Dark and Light IBM Carbon themes.
- Added platform switcher toggling instructions dynamically between Windows (PowerShell) and macOS (Terminal / Zsh).
- Built automated setup scripts: `setup-codex-ica.ps1` for Windows and `setup-codex-ica.sh` for macOS/Linux.

---

## [1.0.0] — 2026-11-13

### 🚀 Initial Release
- Comprehensive analysis of `IBM_Codex_ICA_Getting_Started_Guide.docx`.
- Initial definition of `ica-models.json` and manual setup instructions.

---

## 🛡️ Security & Vulnerability Assessment — Summary

| Assessment Category | Status | Details & Compliance |
|---|:---:|---|
| **Hardcoded Credentials** | **PASSED** | Zero hardcoded keys or passwords in codebase. All keys loaded via secure user input into user-restricted `.env` / User Environment. |
| **Input Validation & Injection** | **PASSED** | TOML config merging strips conflicting sections; JSON catalog is validated via RFC 8259 parser. |
| **File Permissions & ACLs** | **PASSED** | Secrets protected by NTFS owner-only ACLs on Windows and `chmod 600` on macOS/Linux. |
| **Dependency Vulnerabilities** | **PASSED** | Zero external runtime dependencies in `index.html` (pure vanilla HTML5/CSS3/ES6, no external CDNs). Scripts use native OS tools. |
| **Offline Air-Gap Readiness** | **PASSED** | Fully operable within firewalled or air-gapped corporate environments without external network egress. |
| **IBM Security Standards** | **COMPLIANT** | Adheres to IBM Security Meta-Rules, SAML/API key authentication boundaries, and least-privilege principles. |
