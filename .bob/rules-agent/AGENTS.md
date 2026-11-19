# Project Coding Rules (Non-Obvious Only)

Root `AGENTS.md` holds the full gotchas (BOM, TOML key placement, secrets, parity, codex-security). Rules below are only the ones to re-check before editing.

- **File writes**: Never use `Out-File` or `Set-Content` for `config.toml`, `ica-models.json` or `codex-security.yaml`. Use `[System.IO.File]::WriteAllText` with `New-Object System.Text.UTF8Encoding($false)`.
- **Edit both script variants**: A change to `setup-codex-ica.ps1` needs the same change in `setup-codex-ica.sh` (and likewise for the uninstallers). Then run the syntax checks and dry-runs from root `AGENTS.md`.
- **Edit all three `index.html` copies**: The Workstation, Existing Configuration and ChatGPT-manual banners appear in `tab-auto`, `tab-prereqs` and `tab-clients`.
- **Version bumps**: Change `2.3.0` in both setup scripts (header and banner), `index.html`, `README.md`, `plan.md` and `RELEASE_NOTES.md`.
- **WSL exception**: WSL detection/warning exists only in `setup-codex-ica.sh` (warn-only; no `.ps1` equivalent). Don't "fix" parity by porting it, and keep the "Scanning from WSL" content in `README.md` and the `index.html` Troubleshooting FAQ in sync.

