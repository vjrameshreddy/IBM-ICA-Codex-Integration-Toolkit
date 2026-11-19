# IBM ICA (IBM Consulting Advantage) + Codex Integration Toolkit

![Version](https://img.shields.io/badge/version-2.3.0-blue.svg)
![Status](https://img.shields.io/badge/status-active-brightgreen.svg)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS-informational.svg)

A comprehensive setup, automation, and guidance toolkit to configure **OpenAI Codex** (CLI, Visual Studio Code extension, and ChatGPT desktop app) to connect securely with **IBM Consulting Advantage (ICA 2.0)** on **Windows** and **macOS (Apple Silicon)**.

---

## 🚀 Key Deliverables in this Repository

| File | Description |
| :--- | :--- |
| [**`index.html`**](index.html) | **Interactive Web Integration Toolkit** (`v2.3.0`) — A visual, step-by-step assistant for non-technical users and developers with an OS toggle, live config generator, and troubleshooting guide. |
| [**`setup-codex-ica.ps1`**](setup-codex-ica.ps1) | **Windows Automation Script** (`v2.3.0`) — Automated PowerShell setup (directory scaffolding, BOM-free model catalog creation, TOML merging, secure key prompt, and NTFS permissions). |
| [**`setup-codex-ica.sh`**](setup-codex-ica.sh) | **macOS / Linux Automation Script** (`v2.3.0`) — Automated Shell script (npm global prefix fix, model catalog creation, TOML merging, and `chmod 600`). |
| [**`ica-models.json`**](ica-models.json) | **ICA Model Catalog** — Complete, valid JSON definition for all 6 ICA models (`gpt-advantage-assist`, `gpt-5.6-sol`, `gpt-5.6-luna`, `gpt-5.6-terra`, `gpt-5.4`, `gpt-5.1`). |
| [**`RELEASE_NOTES.md`**](RELEASE_NOTES.md) | **Release Notes & Security Assessment** — Complete version history, security vulnerability audit, and filesystem migration records. |
| [**`plan.md`**](plan.md) | **Architecture & Development Plan** — System architecture, client integration boundaries, and maintenance strategy. |
| [**`AGENTS.md`**](AGENTS.md) | **Engineering & Agent Rules** — Non-obvious project knowledge, critical gotchas, and execution commands. |

---

## ⚡ Fast-Track: Automated Installation

> **ℹ️ Prerequisite: install VS Code first.** The script does not install VS Code (IBMers: use `PC@IBM` / `Mac@IBM`). Once VS Code is in place, the script detects and reuses your existing Codex configuration (`~/.codex/config.toml`, `~/.codex/model-catalog/ica-models.json`, `~/.codex/.env`): existing Codex configuration is **preserved and merged** (ICA settings are merged into `config.toml`, other settings are kept, an existing API key can be kept, and the model catalog can be skipped), never overwritten wholesale without your choice. Backups are optional and timestamped, and `-DryRun` / `--dry-run` previews changes without modifying any file.


> **ℹ️ ChatGPT Desktop App is not installed by the automated setup.** Installing it requires administrator privileges, so it must be installed manually, where approved by IBM policy (https://chatgpt.com/download/). The script only configures `~/.codex` so the desktop app can inherit the ICA settings once it is installed. The legacy `-InstallChatGPT` / `--install-chatgpt` flag is a deprecated no-op that prints this message.

### 1. Preview / Dry-Run (No Changes Made)
Inspect planned changes, file diffs, and directory creations before executing:

- **Windows (PowerShell)**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\setup-codex-ica.ps1 -DryRun
  ```
- **macOS (Terminal)**:
  ```bash
  chmod +x setup-codex-ica.sh && ./setup-codex-ica.sh --dry-run
  ```

---

### 2. Run Automated Installation (With Auto-Backup & Overwrite Options)
The script provides a clear action preview and requires your explicit confirmation before applying changes, storing credentials, or terminating daemon processes:

- **Windows (PowerShell)**:
  ```powershell
  # Interactive mode with Auto-Backup & Overwrite prompts for existing files:
  powershell -ExecutionPolicy Bypass -File .\setup-codex-ica.ps1

  # Force automatic timestamped backups without prompting:
  powershell -ExecutionPolicy Bypass -File .\setup-codex-ica.ps1 -AutoBackup

  # Force direct overwrite without creating backup files:
  powershell -ExecutionPolicy Bypass -File .\setup-codex-ica.ps1 -Overwrite
  ```
  *(To bypass interactive confirmation in automated CI workflows, use `-Yes`)*

- **macOS (Terminal)**:
  ```bash
  # Interactive mode with Auto-Backup & Overwrite prompts for existing files:
  chmod +x setup-codex-ica.sh
  ./setup-codex-ica.sh

  # Force automatic timestamped backups without prompting:
  ./setup-codex-ica.sh --auto-backup

  # Force direct overwrite without creating backup files:
  ./setup-codex-ica.sh --overwrite
  ```
  *(To bypass interactive confirmation in automated CI workflows, use `--yes`)*

---

### 🛡️ Safe Backup & Overwrite Safeguards
When existing files (`config.toml`, `.env`, `ica-models.json`) are detected, the tool offers three safe choices:
1. **Auto-Backup and Update** *(Recommended)*: Creates a timestamped `.bak.YYYYMMDD_HHMMSS` copy (with NTFS owner-only or `chmod 600` permissions for `.env`) before updating.
2. **Overwrite In-Place**: Directly replaces configuration without creating `.bak` files.
3. **Keep Existing / Skip**: Retains existing file untouched.

---

## 🌐 Interactive Web Integration Toolkit

For a guided, visual walkthrough tailored for non-technical users:
1. Double-click or open [`index.html`](index.html) in any web browser.
2. Select your operating system (**Windows** or **macOS**).
3. Follow the visual steps, copy single-line commands with 1-click buttons, or generate customized configuration files.

---

## 🎯 Full 5-Step Setup & Verification Roadmap

The integration process consists of 5 clear stages:

| Step | Stage | Description |
|:---:|:---|:---|
| **Step 1** | **Prerequisites** | Verify Node.js, npm, Git, GitHub CLI (`gh`), Python, and install Codex CLI (`@openai/codex`). *(IBMers: Install VS Code via `PC@IBM` / `Mac@IBM`)* |
| **Step 2** | **ICA 2.0 Portal** | Access Essentials Portal and generate a dedicated **Codex Coding Agent API Key**. |
| **Step 3** | **Configuration** | Deploy `ica-models.json`, update `config.toml`, and store `ICA_API_KEY` securely. |
| **Step 4** | **Client Setup** | Install VS Code Extension (`OpenAI.chatgpt`) and (optional) ChatGPT Desktop App, which must be installed **manually** (requires administrator privileges; not installed by the script). *(IBM Workstations: VS Code from `PC@IBM` / `Mac@IBM`)* |
| **Step 5** | **Verification & Testing** | Run the 30-second CLI test, VS Code `hello.py` test prompt, and desktop validation. |

---

### Step 5 Details: End-to-End Verification

#### 5.1 30-Second Terminal Test (CLI)
Open PowerShell or Terminal and run:

- **Windows (PowerShell)**:
  ```powershell
  $env:ICA_API_KEY = [System.Environment]::GetEnvironmentVariable('ICA_API_KEY', 'User')
  New-Item -ItemType Directory -Force "$HOME\codex-ica-test" | Out-Null
  cd "$HOME\codex-ica-test"
  codex
  ```

- **macOS / Linux (Terminal)**:
  ```bash
  mkdir -p "$HOME/codex-ica-test"
  cd "$HOME/codex-ica-test"
  codex
  ```
1. Type `/status` &rarr; verify **`provider: ica`** and **`model: gpt-advantage-assist`**.
2. Send safe test prompt:
   ```text
   Say hello in one sentence. Do not create or modify any files.
   ```
3. Type `/exit` to close.

#### 5.2 VS Code Coding Agent Validation
1. Open **Visual Studio Code** on `~/codex-ica-test`.
2. Open the **Codex icon** in the left Activity Bar.
3. Run the coding verification prompt:
   ```text
   Create a Python program named hello.py that prints "IBM Codex ICA integration successful". Run the program, verify its output, and report the result. Do not modify any other files.
   ```
4. Verify by running: `python hello.py`.

#### 5.3 ChatGPT Desktop App Integration
1. Open a Codex conversation in the desktop app on your `~/codex-ica-test` workspace.
2. Send test prompt: `Say hello in one sentence. Do not create or modify any files.`
3. A successful response confirms the desktop app is using ICA credentials.

---

## 🛠️ Manual Configuration Reference

If you prefer to configure files manually, use the following layout:

### 1. Model Catalog: `~/.codex/model-catalog/ica-models.json`
Create the file in UTF-8 without BOM using the contents of [`ica-models.json`](ica-models.json).

### 2. Codex Configuration: `~/.codex/config.toml`
Place top-level settings before any section headers:
```toml
model = "gpt-advantage-assist"
model_provider = "ica"
model_catalog_json = "C:\\Users\\YOUR_USERNAME\\.codex\\model-catalog\\ica-models.json"
model_reasoning_effort = "medium"

# (Keep existing desktop/plugin configuration here...)

[model_providers.ica]
name = "ICA"
base_url = "https://api.servicesessentials.ibm.com/v1"
wire_api = "responses"
env_key = "ICA_API_KEY"
requires_openai_auth = false
```
*(On macOS, use `/Users/YOUR_USERNAME/.codex/model-catalog/ica-models.json`)*.

### 3. API Key File: `~/.codex/.env`
Create the `.env` file containing:
```env
ICA_API_KEY=YOUR_CODEX_CODING_AGENT_KEY
```

Apply restricted owner-only permissions:
- **Windows**:
  ```powershell
  icacls "$HOME\.codex\.env" /inheritance:r /grant:r "$($env:USERNAME):F"
  ```
- **macOS**:
  ```bash
  chmod 600 ~/.codex/.env
  ```

---

## 🔎 Optional: Codex Security Scans with ICA (Windows)

[`codex-security-ica.ps1`](codex-security-ica.ps1) runs `codex-security scan` against ICA instead of OpenAI.

### How `codex-security` differs from `codex`

- `codex-security` uses its **own Codex home** (`~/.codex/state/plugins/codex-security/codex-home`), not `~/.codex`.
- It **does not inherit the provider configuration** from `~/.codex/config.toml`. A plain `codex-security scan` therefore falls back to stored credentials and OpenAI (web login), even though `codex` itself works with ICA.
- **An explicit ICA provider selection is required** (provider name, `base_url`, `wire_api`, `env_key`). Either a project config file (`-c FILE` / `CODEX_SECURITY_PROJECT_CONFIG`) or `--codex` overrides provide it. The wrapper uses `~/.codex/codex-security.yaml` when present and otherwise falls back to the overrides.
- With those overrides, **both automatic authentication and `--auth api-key` resolve to `ICA_API_KEY`** (confirmed with `--dry-run`: `method: api_key`, `source: ICA_API_KEY`, `modelProvider: ica`). The wrapper uses `--auth api-key` so it never falls back to a web login.
- Do not set `CODEX_SECURITY_STATE_DIR` or copy the ICA key into `OPENAI_API_KEY` (it would be sent to OpenAI). `ICA_API_KEY` and `.env` are used as-is.

### Setup script integration (v2.3.0, opt-in)

`setup-codex-ica.ps1` / `setup-codex-ica.sh` detect `codex-security` and can optionally:

- Install `@openai/codex-security` (prompt **defaults to No**; `-Yes` / `-NonInteractive` / `--yes` do not enable it; Node.js is never upgraded automatically, it needs `^22.13 || ^24 || ^26`).
- Write `~/.codex/codex-security.yaml` (UTF-8 without BOM, **no credentials**; `auth: api-key` and `env_key: ICA_API_KEY`). Existing files follow the usual backup / overwrite / skip prompts.
- Select it through `CODEX_SECURITY_PROJECT_CONFIG` (User environment variable on Windows, `~/.codex/.env` on macOS/Linux). If the variable already points to another file, the conflict is shown and you are asked; it is never replaced silently.

The YAML schema was tested against **codex-security v0.10.0** only. A completed real scan has not been verified on native Windows on the test machine; it did complete from WSL (see [Scanning from WSL](#scanning-from-wsl-workaround-for-the-windows-sandbox-failure)).

### Usage

```powershell
# Preview only: validates inputs and shows the resolved authentication, sends no repository content
.\codex-security-ica.ps1 -DryRun

# Scan another folder: pass it as the repository (first argument)
.\codex-security-ica.ps1 C:\path\to\repo

# Scan selected sub-folders of a repository, or changes against a branch
.\codex-security-ica.ps1 . -Path src,tests
.\codex-security-ica.ps1 -Diff origin/main
```

`-Path` only narrows a scan *inside* the repository; a path outside it is rejected with a hint. To scan another folder, pass that folder as the repository instead.

- Requires `npm install --global @openai/codex-security@latest` and `ICA_API_KEY` (set by the setup script). The key is read from the environment only and is never printed.
- A real scan sends repository content to the ICA endpoint. Confirm this is allowed for the repository before scanning.

### Known limitation (Windows): authentication success is not scan success

Authentication and the Windows sandbox are **two separate problems**. The overrides above fix authentication only. On the machine this was tested on, real scans still stopped at "building threat model", before any model call, with:

```
failed to prepare Windows sandbox ... orchestrator_helper_exit_nonzero: setup helper exited with status Some(1)
```

- `-DryRun` is unaffected, and a plain `codex exec` through ICA works.
- A scan completing end-to-end through ICA was **not verified on native Windows**. The sandbox failure is a separate issue and is not addressed by this script.
- Likely cause: the Codex/ChatGPT desktop app owns the machine-wide Windows sandbox service and accounts, so the scanner's own sandbox setup is refused. Nothing in this toolkit changes that. The WSL route below avoids the Windows sandbox entirely.

### Scanning from WSL (workaround for the Windows sandbox failure)

A full scan completed through ICA from WSL2 on the test machine (WSL2 Ubuntu 26.04, Node.js v22.22.1, `@openai/codex-security` 0.10.1). This is a single scan on one machine and is not verified elsewhere.

**Prerequisites**

- WSL2 with a Linux distribution (e.g. Ubuntu) and a Linux user with `sudo`.
- **Linux-native** Node.js `^22.13 || ^24 || ^26` and npm. Windows copies reached through `/mnt/c/...` do not count. Check that `command -v node npm` prints `/usr/bin/...` paths.
- Your `ICA_API_KEY` (the setup script prompts for it and stores it in `~/.codex/.env`, mode 600).
- The repository to scan, cloned onto the Linux filesystem (`~/...`), not `/mnt/c/...`. A clone contains committed files only.

**Steps (inside the WSL shell)**

```bash
# 1. Linux-native Node.js and npm
sudo apt update && sudo apt install -y nodejs npm
command -v node npm            # must be /usr/bin/node and /usr/bin/npm
node --version                 # must satisfy ^22.13 || ^24 || ^26

# 2. Get the toolkit and run the setup (dry-run first)
git clone https://github.com/vjrameshreddy/IBM-ICA-Codex-Integration-Toolkit.git ~/ica-toolkit
cd ~/ica-toolkit
bash ./setup-codex-ica.sh --dry-run
bash ./setup-codex-ica.sh      # answer Yes to the optional @openai/codex-security install

# 3. Put the npm global bin on PATH (the script cannot persist this when there is no ~/.zshrc)
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.npm-global/bin:$PATH"

# 4. Clone the repository to scan onto the Linux filesystem
git clone <repo-url> ~/my-repo

# 5. Load the ICA key and scan
set -a; . ~/.codex/.env; set +a
codex-security scan ~/my-repo --dry-run   # preview only, sends nothing
codex-security scan ~/my-repo             # real scan: sends repository content to ICA
```

The setup script prints a **WSL warning** when it detects WSL, or when `node`, `npm`, `codex` or `codex-security` resolve to Windows copies under `/mnt/<drive>/`. It only warns; it does not change its behavior. The scanner bundles its own Codex runtime, so a separate native `codex` is not required for scans.

**Where results are**

```
~/.codex/state/plugins/codex-security/scans/<repo-name>/<scan-folder>/
    report.md  threatmodel.md  findings.json  scan-manifest.json
```

```bash
codex-security scans show <scan-id>
codex-security scans logs <scan-id>
```

**Caveats**

- A real scan sends repository content to the ICA endpoint; confirm that is allowed first. A `--dry-run` is not proof that a scan completes.
- If a WSL password is forgotten, reset it from Windows: `wsl -d Ubuntu -u root`, then `passwd <user>`.
- Plain `codex` inside WSL may still resolve to the Windows copy; install a Linux-native one only if you need it.

---

## 🧹 Uninstallation & Fresh Reinstall

If you need to perform a clean reinstall, reset misconfigured settings, or completely remove Codex CLI and ICA configuration, run the automated uninstaller. It asks for one overall confirmation (default No) and then asks again for each item it removes: background daemons, each global npm package, `~/.codex` (with an owner-only backup offer), each User environment variable, the `~/codex-ica-test` workspace, and, on macOS/Linux, the npm user prefix and the `~/.zshrc` PATH line added by the setup.

Prerequisites that the setup can install (Git, GitHub CLI, Node.js, Python) are offered for removal last, one by one, with a default of No. `-Yes` / `--yes` never approve them, because they may predate the setup or be used by other software. ChatGPT Desktop and VS Code are never touched.

```powershell
# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -File .\uninstall-codex-ica.ps1

# Options:
# -DryRun       : Preview actions without modifying any files
# -KeepConfig   : Remove CLI packages and processes, but preserve ~/.codex
# -KeepApiKey   : Preserve ICA_API_KEY in User environment variables
# -Yes          : Assume yes for non-interactive execution
```

```bash
# macOS / Linux (Bash)
./uninstall-codex-ica.sh

# Options: --dry-run, --keep-config, --keep-api-key, --yes
```

---

## ❓ Troubleshooting & Diagnostics

| Symptom / Error | Root Cause | Solution |
| :--- | :--- | :--- |
| `failed to parse model_catalog_json ... expected value at line 1 column 1` | `ica-models.json` contains a UTF-8 Byte Order Mark (BOM). | Re-save the file as pure UTF-8 (No BOM) or run `setup-codex-ica.ps1`. |
| `Missing environment variable: ICA_API_KEY` | Codex background daemon server (`codex.exe`) is caching an old environment. | Terminate stale daemon processes: `Get-Process -Name 'codex', 'node_repl' \| Stop-Process -Force` and reload `$env:ICA_API_KEY`. |
| `running scripts is disabled on this system` | PowerShell execution policy restriction. | Run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` or use `codex.cmd`. |
| `/status shows provider: openai instead of ica` | Top-level settings in `config.toml` placed below a `[section]` header. | Move the 4 top-level settings to the very top of `~/.codex/config.toml`. |
| `npm EACCES permission error` (macOS) | Global npm folder requiring root permissions. | Configure user prefix: `npm config set prefix "$HOME/.npm-global"` (handled automatically by `setup-codex-ica.sh`). |
| `.env.txt` or `ica-models.json.txt` created | Windows Notepad appending `.txt` extension. | In File Explorer, enable **View > Show > File name extensions** and remove the trailing `.txt`. |

---

## 🔒 Security & IBM Policy Requirements

- **API Keys are Secrets**: Treat your ICA Coding Agent API Key as confidential. Never commit `.env` or `config.toml` containing credentials to source control, chat channels, or screenshots.
- **Separate Work and Personal Profiles**: Keep your personal ChatGPT accounts strictly separate from IBM work directories.
- **Dedicated Team Isolation**: Use an authorized ICA 2.0 team for coding agent workflows.
