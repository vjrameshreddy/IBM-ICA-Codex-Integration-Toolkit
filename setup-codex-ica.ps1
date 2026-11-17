# ==============================================================================
# IBM ICA (IBM Consulting Advantage) + Codex Automated Setup Script for Windows
# Version: 2.3.0
# ==============================================================================
[CmdletBinding()]
param(
    [Alias("Preview", "Plan")]
    [switch]$DryRun,

    [Alias("AssumeYes")]
    [switch]$Yes,

    [switch]$AutoBackup,
    [switch]$Overwrite,
    # Deprecated no-op (kept so existing automation does not break): ChatGPT Desktop is no longer installed by this script.
    [switch]$InstallChatGPT,
    [switch]$SkipKeyPrompt,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Text)
    Write-Host "`n[+] $Text" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Text)
    Write-Host " [OK] $Text" -ForegroundColor Green
}

function Write-WarningMsg {
    param([string]$Text)
    Write-Host " [WARN] $Text" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Text)
    Write-Host " [ERROR] $Text" -ForegroundColor Red
}

function Write-HeaderBox {
    param([string]$Title, [string]$Subtitle)
    Write-Host "`n=================================================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor White
    if ($Subtitle) {
        Write-Host "  $Subtitle" -ForegroundColor DarkCyan
    }
    Write-Host "=================================================================" -ForegroundColor Cyan
}

function Ask-UserApproval {
    param([string]$PromptText, [bool]$DefaultYes = $true)
    
    if ($Yes -or $NonInteractive -or $AutoBackup -or $Overwrite) {
        return $DefaultYes
    }
    
    $options = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    $response = Read-Host "$PromptText $options"
    
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $DefaultYes
    }
    
    return ($response.Trim().ToLower() -eq 'y' -or $response.Trim().ToLower() -eq 'yes')
}

function Backup-ConfigFile {
    param(
        [string]$Path,
        [string]$Description,
        [bool]$IsSecret = $false
    )
    if (-not (Test-Path $Path)) { return }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $bakFile = "$Path.bak.$timestamp"
    try {
        Copy-Item -Path $Path -Destination $bakFile -Force
        if ($IsSecret) {
            $currentUser = $env:USERNAME
            & icacls "$bakFile" /inheritance:r /grant:r "${currentUser}:F" 2>$null | Out-Null
        }
        Write-Success "Backup created for $Description -> $bakFile"
    } catch {
        Write-WarningMsg "Could not backup $Description`: $_"
    }
}

function Prompt-FileAction {
    param(
        [string]$FilePath,
        [string]$Description
    )
    if (-not (Test-Path $FilePath)) {
        return "Write"
    }
    if ($AutoBackup) {
        return "BackupAndUpdate"
    }
    if ($Overwrite) {
        return "Overwrite"
    }
    if ($Yes -or $NonInteractive) {
        return "BackupAndUpdate"
    }
    
    Write-Host "`n [!] Existing $Description detected at $FilePath" -ForegroundColor Yellow
    Write-Host "     [1] Auto-Backup and Update (Recommended - creates a timestamped .bak file)" -ForegroundColor Cyan
    Write-Host "     [2] Overwrite in-place (no backup file)" -ForegroundColor DarkYellow
    Write-Host "     [3] Skip modifying this file" -ForegroundColor DarkGray
    $choice = Read-Host "     Select option [1/2/3] (Default: 1)"
    
    switch ($choice.Trim()) {
        "2" { return "Overwrite" }
        "3" { return "Skip" }
        Default { return "BackupAndUpdate" }
    }
}

function Get-CodexSecurityVersion {
    try {
        $out = & codex-security --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $out) { return ("$out").Trim() }
    } catch {}
    return $null
}

# @openai/codex-security (v0.10.0) requires Node.js ^22.13.0 || ^24.0.0 || ^26.0.0
function Test-NodeForCodexSecurity {
    param([string]$NodeVersion)
    if ($NodeVersion -notmatch '^v?(\d+)\.(\d+)') { return $false }
    $major = [int]$Matches[1]; $minor = [int]$Matches[2]
    return (($major -eq 22 -and $minor -ge 13) -or $major -eq 24 -or $major -eq 26)
}

Clear-Host
Write-HeaderBox "IBM ICA (IBM Consulting Advantage) + Codex Setup Tool v2.3.0" "Windows Edition with Dry-Run Preview & Explicit Confirmation"

Write-Host "[INFO] ChatGPT Desktop App is not installed by the automated setup." -ForegroundColor Cyan
Write-Host "       Installing it requires administrator privileges, so it must be installed manually," -ForegroundColor Cyan
Write-Host "       where approved by IBM policy (https://chatgpt.com/download/). This script only configures" -ForegroundColor Cyan
Write-Host "       ~/.codex so the desktop app can inherit the ICA settings once it is installed." -ForegroundColor Cyan
if ($InstallChatGPT) {
    Write-Host "[WARN] The -InstallChatGPT / --install-chatgpt flag is deprecated and ignored: ChatGPT Desktop is no longer installed by this script. Please install it manually (administrator privileges required)." -ForegroundColor Yellow
}

# 1. Environment & Path Definitions
$CodexDir = Join-Path $HOME ".codex"
$ModelCatalogDir = Join-Path $CodexDir "model-catalog"
$CatalogJsonFile = Join-Path $ModelCatalogDir "ica-models.json"
$ConfigFile = Join-Path $CodexDir "config.toml"
$EnvFile = Join-Path $CodexDir ".env"
$SecurityConfigFile = Join-Path $CodexDir "codex-security.yaml"
$TestDir = Join-Path $HOME "codex-ica-test"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# 2. Check Prerequisites
Write-Step "Inspecting current system environment..."

$Prereqs = @{
    "Node.js" = "node -v"
    "npm"     = "npm -v"
    "Git"     = "git --version"
    "Python"  = "python --version"
    "VS Code" = "code --version"
}

$ToolStatus = @{}
foreach ($Tool in $Prereqs.Keys) {
    try {
        $cmd = $Prereqs[$Tool]
        $output = Invoke-Expression $cmd 2>$null
        if ($LASTEXITCODE -eq 0 -and $output) {
            $ToolStatus[$Tool] = $output.Trim()
            Write-Success "$Tool found: $($ToolStatus[$Tool])"
        } else {
            $ToolStatus[$Tool] = $null
            if ($Tool -eq "VS Code") {
                Write-WarningMsg "VS Code not found or not in PATH. (IBMers: Install via official 'PC@IBM' internal software catalog)"
            } else {
                Write-WarningMsg "$Tool not found or not in PATH."
            }
        }
    } catch {
        $ToolStatus[$Tool] = $null
        if ($Tool -eq "VS Code") {
            Write-WarningMsg "VS Code is missing. (IBMers: Install via official 'PC@IBM' internal software catalog)"
        } else {
            Write-WarningMsg "$Tool is missing."
        }
    }
}

# Check Codex CLI
$CodexVer = $null
try {
    $codexOut = Invoke-Expression "codex --version" 2>$null
    if ($LASTEXITCODE -eq 0 -and $codexOut) {
        $CodexVer = $codexOut.Trim()
        Write-Success "Codex CLI found: $CodexVer"
    }
} catch {}

if (-not $CodexVer) {
    Write-WarningMsg "Codex CLI (@openai/codex) is not currently installed."
}

# Check Codex Security (optional scanner)
$SecurityVer = Get-CodexSecurityVersion
if ($SecurityVer) {
    Write-Success "Codex Security found: $SecurityVer"
} else {
    Write-Host " [INFO] Codex Security (@openai/codex-security) is not installed (optional scanner)." -ForegroundColor DarkGray
}

# Missing prerequisites that can be installed automatically via winget.
# VS Code is intentionally excluded: IBM-managed machines must install it via PC@IBM / Mac@IBM.
$WingetPackages = [ordered]@{
    "Git"     = "Git.Git"
    "Node.js" = "OpenJS.NodeJS.LTS"
    "Python"  = "Python.Python.3.14"
}
$MissingPrereqs = @()
foreach ($Tool in $WingetPackages.Keys) {
    if (-not $ToolStatus[$Tool]) { $MissingPrereqs += $Tool }
}
# npm ships with Node.js, so a missing npm also requires installing Node.js LTS
if (-not $ToolStatus["npm"] -and $MissingPrereqs -notcontains "Node.js") { $MissingPrereqs += "Node.js" }

# Check running background daemons
$RunningDaemons = @()
try {
    $RunningDaemons = Get-Process -Name 'codex', 'node_repl' -ErrorAction SilentlyContinue
} catch {}

# Check existing configuration files & ChatGPT desktop installation
$HasCatalog = Test-Path $CatalogJsonFile
$HasConfig = Test-Path $ConfigFile
$HasEnv = Test-Path $EnvFile
$HasTestDir = Test-Path $TestDir

$HasChatGPTDesktop = $false
if (Test-Path "$env:LOCALAPPDATA\Programs\ChatGPT\ChatGPT.exe") {
    $HasChatGPTDesktop = $true
} elseif (Test-Path "$env:ProgramFiles\ChatGPT\ChatGPT.exe") {
    $HasChatGPTDesktop = $true
}

# 3. Model Catalog Definition (Pure RFC 8259 JSON)
$ModelCatalogContent = @'
{
  "models": [
    {
      "slug": "gpt-advantage-assist",
      "display_name": "GPT Advantage Assist",
      "description": "GPT Advantage Assist from ICA",
      "default_reasoning_level": "medium",
      "base_instructions": "You are Codex, an AI coding agent. Follow the user's request, inspect relevant files before editing, make focused changes, use available tools appropriately, and verify completed work.",
      "supported_reasoning_levels": [
        {
          "effort": "low",
          "description": "Faster responses with lighter reasoning"
        },
        {
          "effort": "medium",
          "description": "Balanced speed and reasoning"
        },
        {
          "effort": "high",
          "description": "Deeper reasoning for complex tasks"
        },
        {
          "effort": "xhigh",
          "description": "Maximum reasoning for difficult tasks"
        }
      ],
      "shell_type": "shell_command",
      "visibility": "list",
      "supported_in_api": true,
      "support_verbosity": true,
      "truncation_policy": {
        "mode": "bytes",
        "limit": 10000
      },
      "experimental_supported_tools": [],
      "priority": 0,
      "upgrade": null
    },
    {
      "slug": "gpt-5.6-sol",
      "display_name": "GPT-5.6 Sol",
      "description": "GPT-5.6 Sol from ICA",
      "default_reasoning_level": "medium",
      "base_instructions": "You are Codex, an AI coding agent. Follow the user's request, inspect relevant files before editing, make focused changes, use available tools appropriately, and verify completed work.",
      "supported_reasoning_levels": [
        {
          "effort": "low",
          "description": "Faster responses with lighter reasoning"
        },
        {
          "effort": "medium",
          "description": "Balanced speed and reasoning"
        },
        {
          "effort": "high",
          "description": "Deeper reasoning for complex tasks"
        },
        {
          "effort": "xhigh",
          "description": "Maximum reasoning for difficult tasks"
        }
      ],
      "shell_type": "shell_command",
      "visibility": "list",
      "supported_in_api": true,
      "support_verbosity": true,
      "truncation_policy": {
        "mode": "bytes",
        "limit": 10000
      },
      "experimental_supported_tools": [],
      "priority": 0,
      "upgrade": null
    },
    {
      "slug": "gpt-5.6-luna",
      "display_name": "GPT-5.6 Luna",
      "description": "GPT-5.6 Luna from ICA",
      "default_reasoning_level": "medium",
      "base_instructions": "You are Codex, an AI coding agent. Follow the user's request, inspect relevant files before editing, make focused changes, use available tools appropriately, and verify completed work.",
      "supported_reasoning_levels": [
        {
          "effort": "low",
          "description": "Faster responses with lighter reasoning"
        },
        {
          "effort": "medium",
          "description": "Balanced speed and reasoning"
        },
        {
          "effort": "high",
          "description": "Deeper reasoning for complex tasks"
        },
        {
          "effort": "xhigh",
          "description": "Maximum reasoning for difficult tasks"
        }
      ],
      "shell_type": "shell_command",
      "visibility": "list",
      "supported_in_api": true,
      "support_verbosity": true,
      "truncation_policy": {
        "mode": "bytes",
        "limit": 10000
      },
      "experimental_supported_tools": [],
      "priority": 0,
      "upgrade": null
    },
    {
      "slug": "gpt-5.6-terra",
      "display_name": "GPT-5.6 Terra",
      "description": "GPT-5.6 Terra from ICA",
      "default_reasoning_level": "medium",
      "base_instructions": "You are Codex, an AI coding agent. Follow the user's request, inspect relevant files before editing, make focused changes, use available tools appropriately, and verify completed work.",
      "supported_reasoning_levels": [
        {
          "effort": "low",
          "description": "Faster responses with lighter reasoning"
        },
        {
          "effort": "medium",
          "description": "Balanced speed and reasoning"
        },
        {
          "effort": "high",
          "description": "Deeper reasoning for complex tasks"
        },
        {
          "effort": "xhigh",
          "description": "Maximum reasoning for difficult tasks"
        }
      ],
      "shell_type": "shell_command",
      "visibility": "list",
      "supported_in_api": true,
      "support_verbosity": true,
      "truncation_policy": {
        "mode": "bytes",
        "limit": 10000
      },
      "experimental_supported_tools": [],
      "priority": 0,
      "upgrade": null
    },
    {
      "slug": "gpt-5.4",
      "display_name": "GPT-5.4",
      "description": "GPT-5.4 from ICA",
      "default_reasoning_level": "medium",
      "base_instructions": "You are Codex, an AI coding agent. Follow the user's request, inspect relevant files before editing, make focused changes, use available tools appropriately, and verify completed work.",
      "supported_reasoning_levels": [
        {
          "effort": "low",
          "description": "Faster responses with lighter reasoning"
        },
        {
          "effort": "medium",
          "description": "Balanced speed and reasoning"
        },
        {
          "effort": "high",
          "description": "Deeper reasoning for complex tasks"
        },
        {
          "effort": "xhigh",
          "description": "Maximum reasoning for difficult tasks"
        }
      ],
      "shell_type": "shell_command",
      "visibility": "list",
      "supported_in_api": true,
      "support_verbosity": true,
      "truncation_policy": {
        "mode": "bytes",
        "limit": 10000
      },
      "experimental_supported_tools": [],
      "priority": 0,
      "upgrade": null
    },
    {
      "slug": "gpt-5.1",
      "display_name": "GPT-5.1",
      "description": "GPT-5.1 from ICA",
      "default_reasoning_level": "medium",
      "base_instructions": "You are Codex, an AI coding agent. Follow the user's request, inspect relevant files before editing, make focused changes, use available tools appropriately, and verify completed work.",
      "supported_reasoning_levels": [
        {
          "effort": "low",
          "description": "Faster responses with lighter reasoning"
        },
        {
          "effort": "medium",
          "description": "Balanced speed and reasoning"
        },
        {
          "effort": "high",
          "description": "Deeper reasoning for complex tasks"
        },
        {
          "effort": "xhigh",
          "description": "Maximum reasoning for difficult tasks"
        }
      ],
      "shell_type": "shell_command",
      "visibility": "list",
      "supported_in_api": true,
      "support_verbosity": true,
      "truncation_policy": {
        "mode": "bytes",
        "limit": 10000
      },
      "experimental_supported_tools": [],
      "priority": 0,
      "upgrade": null
    }
  ]
}
'@

# Codex Security project configuration (YAML). Contains NO credentials: it only names the ICA_API_KEY environment variable.
# Keys tested against @openai/codex-security v0.10.0 (schema: project-config.schema.json).
$SecurityConfigContent = @'
# codex-security project configuration for IBM Consulting Advantage (ICA).
# Written by setup-codex-ica; keys tested against @openai/codex-security v0.10.0.
# Contains NO credentials: the key is read from the ICA_API_KEY environment variable.
auth: api-key
codex:
  model: gpt-advantage-assist
  model_provider: ica
  model_providers:
    ica:
      name: ICA
      base_url: https://api.servicesessentials.ibm.com/v1
      wire_api: responses
      env_key: ICA_API_KEY
'@
$SecurityConfigContent = $SecurityConfigContent -replace "`r`n", "`n"
$HasSecurityConfig = Test-Path $SecurityConfigFile

# 4. Compute Merged config.toml Content
$EscapedCatalogPath = $CatalogJsonFile.Replace('\', '\\')

$TopLevelSettings = @"
model = "gpt-advantage-assist"
model_provider = "ica"
model_catalog_json = "$EscapedCatalogPath"
model_reasoning_effort = "medium"
"@

$ProviderSection = @"
[model_providers.ica]
name = "ICA"
base_url = "https://api.servicesessentials.ibm.com/v1"
wire_api = "responses"
env_key = "ICA_API_KEY"
requires_openai_auth = false
"@

$FinalConfigContent = ""
if (Test-Path $ConfigFile) {
    $ExistingLines = Get-Content $ConfigFile
    $FilteredLines = @()
    $InIcaSection = $false
    
    foreach ($Line in $ExistingLines) {
        $trimmed = $Line.Trim()
        if ($trimmed -match '^\[model_providers\.ica\]') {
            $InIcaSection = $true
            continue
        } elseif ($InIcaSection -and $trimmed -match '^\[') {
            $InIcaSection = $false
        }
        if ($InIcaSection) { continue }
        if ($trimmed -match '^(model|model_provider|model_catalog_json|model_reasoning_effort)\s*=') { continue }
        $FilteredLines += $Line
    }
    $FinalConfigContent = "$TopLevelSettings`r`n`r`n" + ($FilteredLines -join "`r`n") + "`r`n`r`n$ProviderSection`r`n"
} else {
    $FinalConfigContent = "$TopLevelSettings`r`n`r`n$ProviderSection`r`n"
}

# ==============================================================================
# PREVIEW / DRY-RUN SUMMARY (REQUIRED BEHAVIOR)
# ==============================================================================
Write-Host "`n+---------------------------------------------------------------+" -ForegroundColor Yellow
Write-Host "|                 PLANNED ACTIONS PREVIEW                       |" -ForegroundColor Yellow
Write-Host "+---------------------------------------------------------------+" -ForegroundColor Yellow

Write-Host " 1. Directory Structure:" -ForegroundColor White
Write-Host "    - Model Catalog Folder : $ModelCatalogDir $(if ($HasCatalog) { '[Exists]' } else { '[Will Create]' })" -ForegroundColor Gray
Write-Host "    - Test Workspace Folder: $TestDir $(if ($HasTestDir) { '[Exists]' } else { '[Will Create]' })" -ForegroundColor Gray

Write-Host "`n 2. Configuration Files:" -ForegroundColor White
Write-Host "    - Note: Existing Codex configuration is preserved and merged: ICA settings are merged into config.toml, an existing API key can be kept, and each existing file can be backed up (timestamped, optional) or skipped. VS Code is not installed by this script." -ForegroundColor DarkGray
Write-Host "    - Model Catalog ($CatalogJsonFile):" -ForegroundColor Gray
Write-Host "      Will write 6 ICA models (gpt-advantage-assist, gpt-5.6-sol, etc.) in UTF-8 without BOM.$(if ($HasCatalog) { ' [Auto-Backup offered]' })" -ForegroundColor DarkGray
Write-Host "    - Codex Config ($ConfigFile):" -ForegroundColor Gray
Write-Host "      Will $(if ($HasConfig) { 'merge with existing config [Auto-Backup offered]' } else { 'create new config' }) placing top-level ICA settings at top." -ForegroundColor DarkGray

Write-Host "    - Codex Security Config ($SecurityConfigFile):" -ForegroundColor Gray
if ($SecurityVer) {
    Write-Host "      Will $(if ($HasSecurityConfig) { 'update existing config [Auto-Backup offered]' } else { 'create new config' }) (UTF-8 without BOM, no credentials; auth: api-key, env_key: ICA_API_KEY)." -ForegroundColor DarkGray
    $existingSel = [System.Environment]::GetEnvironmentVariable('CODEX_SECURITY_PROJECT_CONFIG', 'User')
    if ([string]::IsNullOrWhiteSpace($existingSel)) {
        Write-Host "      Will set User env var CODEX_SECURITY_PROJECT_CONFIG to this file." -ForegroundColor DarkGray
    } elseif ($existingSel -ne $SecurityConfigFile) {
        Write-Host "      CONFLICT: CODEX_SECURITY_PROJECT_CONFIG already points to $existingSel - will ask before replacing it." -ForegroundColor Yellow
    } else {
        Write-Host "      CODEX_SECURITY_PROJECT_CONFIG already points to this file." -ForegroundColor DarkGray
    }
} else {
    Write-Host "      Only written if codex-security is installed (optional install prompt defaults to No)." -ForegroundColor DarkGray
}

Write-Host "`n 3. Secret & Environment Management:" -ForegroundColor White
Write-Host "    - Secret File : $EnvFile (Will store ICA_API_KEY with owner-only NTFS permissions$(if ($HasEnv) { ', Auto-Backup offered' }))" -ForegroundColor Gray
Write-Host "    - Environment : Will register ICA_API_KEY in Windows User Environment variables" -ForegroundColor Gray

Write-Host "`n 4. Process & Extension Management:" -ForegroundColor White
if ($MissingPrereqs.Count -gt 0) {
    Write-Host "    - Prerequisites: Will offer to install via winget: $($MissingPrereqs -join ', ')" -ForegroundColor Yellow
} else {
    Write-Host "    - Prerequisites: Git, Node.js, npm and Python already installed" -ForegroundColor Gray
}
if (-not $ToolStatus["VS Code"]) {
    Write-Host "    - VS Code     : Missing - install manually via 'PC@IBM' (not installed by this script)" -ForegroundColor Yellow
}
if (-not $CodexVer) {
    Write-Host "    - Software    : Will offer to install @openai/codex globally via npm" -ForegroundColor Yellow
} else {
    Write-Host "    - Software    : Codex CLI already installed ($CodexVer)" -ForegroundColor Gray
}
if ($SecurityVer) {
    Write-Host "    - Codex Security: Already installed ($SecurityVer)" -ForegroundColor Gray
} else {
    Write-Host "    - Codex Security: Optional - will ask before installing @openai/codex-security (default: No; needs Node.js 22.13+/24/26, Node is never upgraded automatically)" -ForegroundColor Yellow
}
if ($HasChatGPTDesktop) {
    Write-Host "    - ChatGPT App : Desktop app detected (Will inherit ICA config automatically)" -ForegroundColor Gray
} else {
    Write-Host "    - ChatGPT App : Not installed - NOT installed by this script; install manually (requires administrator privileges)" -ForegroundColor Yellow
}
if ($RunningDaemons.Count -gt 0) {
    Write-Host "    - Daemons     : Will terminate $($RunningDaemons.Count) running codex/node_repl processes to reload environment" -ForegroundColor Yellow
} else {
    Write-Host "    - Daemons     : No stale background daemons running" -ForegroundColor Gray
}

Write-Host "+---------------------------------------------------------------+`n" -ForegroundColor Yellow

# If Dry-Run requested, display detailed preview and exit
if ($DryRun) {
    Write-Host "[DRY-RUN MODE ACTIVATED] Detailed file preview:" -ForegroundColor Cyan
    Write-Host "`n--- config.toml Preview ---" -ForegroundColor DarkCyan
    Write-Host $FinalConfigContent -ForegroundColor Gray
    Write-Host "--- End config.toml Preview ---`n" -ForegroundColor DarkCyan

    Write-Host "`n--- codex-security.yaml Preview (no credentials) ---" -ForegroundColor DarkCyan
    Write-Host $SecurityConfigContent -ForegroundColor Gray
    Write-Host "--- End codex-security.yaml Preview ---`n" -ForegroundColor DarkCyan

    Write-Host "[DRY-RUN] No changes were made to your system. To apply these changes, run without -DryRun." -ForegroundColor Green
    Write-Host "[DRY-RUN] This is a preview only. It is not a completed setup, and a codex-security dry-run never proves that a scan completes." -ForegroundColor DarkGray
    exit 0
}

# ==============================================================================
# EXPLICIT USER CONFIRMATION (REQUIRED BEHAVIOR)
# ==============================================================================
$Proceed = Ask-UserApproval "Do you want to proceed with executing the planned setup actions?" $true

if (-not $Proceed) {
    Write-WarningMsg "Setup cancelled by user. No files or settings were modified."
    exit 0
}

# ------------------------------------------------------------------------------
# STEP 0: Install missing prerequisites (Git, Node.js/npm, Python) via winget
# ------------------------------------------------------------------------------
if ($MissingPrereqs.Count -gt 0) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        foreach ($Tool in $MissingPrereqs) {
            $PackageId = $WingetPackages[$Tool]
            if (Ask-UserApproval "$Tool is missing. Install $PackageId via winget now?" $true) {
                Write-Step "Installing $Tool ($PackageId) via winget..."
                try {
                    & winget install --id $PackageId -e --accept-package-agreements --accept-source-agreements
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "$Tool installed successfully."
                    } else {
                        Write-WarningMsg "winget could not install $Tool (exit code $LASTEXITCODE). Install it manually and re-run this script."
                    }
                } catch {
                    Write-WarningMsg "Could not invoke winget for ${Tool}: $_"
                }
            }
        }
        # Reload PATH so newly installed tools (node, npm, git) are visible in this session
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
        foreach ($Cmd in @('git', 'node', 'npm')) {
            if (-not (Get-Command $Cmd -ErrorAction SilentlyContinue)) {
                Write-WarningMsg "$Cmd is still not on PATH. Open a new terminal after setup completes."
            }
        }
    } else {
        Write-WarningMsg "winget is not available. Install manually: Git (https://git-scm.com/), Node.js LTS (https://nodejs.org/), Python (https://www.python.org/)."
    }
}

# ------------------------------------------------------------------------------
# STEP 1: Install Codex CLI (if missing) with explicit confirmation
# ------------------------------------------------------------------------------
if (-not $CodexVer) {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        $InstallCodex = Ask-UserApproval "Codex CLI (@openai/codex) is missing. Install globally now via npm?" $true
        if ($InstallCodex) {
            Write-Step "Installing @openai/codex globally via npm..."
            npm install -g @openai/codex
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Codex CLI installed successfully."
                $CodexVer = "Installed"
            } else {
                Write-ErrorMsg "Failed to install Codex CLI. Please check your npm permissions."
            }
        }
    } else {
        Write-WarningMsg "npm is not installed. Please install Node.js LTS from https://nodejs.org/ first."
    }
}

# ------------------------------------------------------------------------------
# STEP 2: Create Directories
# ------------------------------------------------------------------------------
Write-Step "Creating directories..."
if (-not (Test-Path $ModelCatalogDir)) {
    New-Item -ItemType Directory -Force -Path $ModelCatalogDir | Out-Null
    Write-Success "Created: $ModelCatalogDir"
} else {
    Write-Success "Verified: $ModelCatalogDir"
}

if (-not (Test-Path $TestDir)) {
    New-Item -ItemType Directory -Force -Path $TestDir | Out-Null
    Write-Success "Created: $TestDir"
} else {
    Write-Success "Verified: $TestDir"
}

# ------------------------------------------------------------------------------
# STEP 3: Write ica-models.json (RFC 8259 Pure UTF-8 without BOM)
# ------------------------------------------------------------------------------
Write-Step "Configuring ICA Model Catalog (ica-models.json)..."
$catalogAction = Prompt-FileAction $CatalogJsonFile "model catalog (ica-models.json)"
if ($catalogAction -eq "BackupAndUpdate") {
    Backup-ConfigFile $CatalogJsonFile "model catalog (ica-models.json)"
}
if ($catalogAction -ne "Skip") {
    [System.IO.File]::WriteAllText($CatalogJsonFile, $ModelCatalogContent, $Utf8NoBom)
    try {
        $null = Get-Content $CatalogJsonFile -Raw | ConvertFrom-Json
        Write-Success "ica-models.json written and validated successfully."
    } catch {
        Write-ErrorMsg "Failed to validate generated ica-models.json: $_"
    }
} else {
    Write-WarningMsg "Skipped modifying ica-models.json as requested."
}

# ------------------------------------------------------------------------------
# STEP 4: Configure config.toml
# ------------------------------------------------------------------------------
Write-Step "Configuring config.toml..."
$configAction = Prompt-FileAction $ConfigFile "Codex config (config.toml)"
if ($configAction -eq "BackupAndUpdate") {
    Backup-ConfigFile $ConfigFile "config.toml"
}
if ($configAction -ne "Skip") {
    [System.IO.File]::WriteAllText($ConfigFile, $FinalConfigContent, $Utf8NoBom)
    Write-Success "config.toml updated with ICA model provider and catalog path."
} else {
    Write-WarningMsg "Skipped modifying config.toml as requested."
}

# ------------------------------------------------------------------------------
# STEP 5: Secure API Key Configuration
# ------------------------------------------------------------------------------
Write-Step "Configuring ICA API Key..."

if ($SkipKeyPrompt) {
    Write-WarningMsg "Skipping API key prompt as requested."
} else {
    $ApiKey = $null
    $ShouldWriteEnv = $true
    
    if (Test-Path $EnvFile) {
        $ExistingEnv = Get-Content $EnvFile -Raw -ErrorAction SilentlyContinue
        if ($ExistingEnv -match 'ICA_API_KEY=\s*(\S+)' -and $Matches[1] -ne 'REPLACE_WITH_YOUR_NEW_CODEX_CODING_AGENT_KEY') {
            Write-Success "An existing ICA_API_KEY was found in $EnvFile."
            if ($AutoBackup) {
                $ApiKey = $Matches[1]
                $ShouldWriteEnv = $false
                Write-Success "Retained active ICA_API_KEY."
            } elseif ($Overwrite) {
                $ApiKey = $null
            } else {
                Write-Host "`n [!] Existing .env secret file detected." -ForegroundColor Yellow
                Write-Host "     [1] Keep existing key (Recommended)" -ForegroundColor Cyan
                Write-Host "     [2] Auto-Backup .env and enter a new key" -ForegroundColor DarkCyan
                Write-Host "     [3] Overwrite .env in-place with new key" -ForegroundColor DarkYellow
                Write-Host "     [4] Skip secret configuration" -ForegroundColor DarkGray
                $keyChoice = Read-Host "     Select option [1/2/3/4] (Default: 1)"
                
                switch ($keyChoice.Trim()) {
                    "2" {
                        Backup-ConfigFile $EnvFile ".env (secret)" -IsSecret $true
                        $ApiKey = $null
                    }
                    "3" {
                        $ApiKey = $null
                    }
                    "4" {
                        $ShouldWriteEnv = $false
                    }
                    Default {
                        $ApiKey = $Matches[1]
                        $ShouldWriteEnv = $false
                        Write-Success "Retained active ICA_API_KEY."
                    }
                }
            }
        }
    }
    
    if ($ShouldWriteEnv -and (-not $ApiKey)) {
        Write-Host "To obtain your Coding Agent API key:" -ForegroundColor Cyan
        Write-Host " 1. Sign in to https://servicesessentials.ibm.com/" -ForegroundColor Gray
        Write-Host " 2. Select/Create your 2.0 team (e.g. '<YourName> Codex Training')" -ForegroundColor Gray
        Write-Host " 3. Settings > API Keys > Coding Agents > Generate Coding Agent API Key" -ForegroundColor Gray
        Write-Host " 4. Copy the key from the 'Codex' row (NOT general ICA key)" -ForegroundColor Gray
        Write-Host ""
        
        $SecureString = Read-Host "Paste your Codex Coding Agent API Key (input will be hidden)" -AsSecureString
        if ($SecureString) {
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
            $ApiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        }
    }
    
    if ($ShouldWriteEnv -and (-not [string]::IsNullOrWhiteSpace($ApiKey))) {
        $EnvContent = "ICA_API_KEY=$ApiKey`r`n"
        [System.IO.File]::WriteAllText($EnvFile, $EnvContent, $Utf8NoBom)
        
        # Apply strict NTFS owner-only permissions
        try {
            $currentUser = $env:USERNAME
            & icacls "$EnvFile" /inheritance:r /grant:r "${currentUser}:F" 2>$null | Out-Null
            Write-Success ".env file created with strict user-only permissions."
        } catch {
            Write-WarningMsg "Could not set icacls permissions on .env file: $_"
        }
    }
    
    # Set for current PowerShell session & persistent User Environment Variable if key exists
    if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
        $env:ICA_API_KEY = $ApiKey
        try {
            [System.Environment]::SetEnvironmentVariable('ICA_API_KEY', $ApiKey, 'User')
            Write-Success "Registered ICA_API_KEY user environment variable for VS Code and GUI apps."
        } catch {}
    } elseif (-not $ShouldWriteEnv) {
        Write-Success ".env retained untouched."
    } else {
        Write-WarningMsg "No API key was entered. You will need to manually configure $EnvFile later."
    }
}

# ------------------------------------------------------------------------------
# STEP 5b: Codex Security (optional scanner): install (opt-in) + project configuration
# ------------------------------------------------------------------------------
$SecurityConfigured = $false
Write-Step "Codex Security (optional scanner)..."

if (-not $SecurityVer) {
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-WarningMsg "npm is not available, so codex-security cannot be installed. Install Node.js LTS first, then re-run this script."
    } else {
        $NodeNow = $null
        try { $NodeNow = (& node -v 2>$null) } catch {}
        if (-not (Test-NodeForCodexSecurity $NodeNow)) {
            Write-WarningMsg "codex-security requires Node.js 22.13+, 24.x or 26.x (found: $(if ($NodeNow) { $NodeNow } else { 'none' })). Node.js is NOT upgraded automatically; skipping codex-security installation."
        } else {
            if (Ask-UserApproval "Install the optional codex-security scanner globally via npm (@openai/codex-security)? It needs Node.js and Python 3.10+." $false) {
                Write-Step "Installing @openai/codex-security globally via npm..."
                npm install -g @openai/codex-security@latest
                if ($LASTEXITCODE -eq 0) {
                    $SecurityVer = Get-CodexSecurityVersion
                    if ($SecurityVer) { Write-Success "codex-security installed: $SecurityVer" }
                    else { Write-WarningMsg "codex-security was installed but is not on PATH yet. Open a new terminal and re-run this script to configure it." }
                } else {
                    Write-ErrorMsg "Failed to install codex-security. Please check your npm permissions."
                }
            } else {
                Write-Host " [SKIP] codex-security installation not selected (optional). Re-run this script later to add it." -ForegroundColor DarkGray
            }
        }
    }
}

if ($SecurityVer) {
    # Project configuration file. Contains NO credentials: it only names the ICA_API_KEY environment variable.
    $securityAction = Prompt-FileAction $SecurityConfigFile "Codex Security project config (codex-security.yaml)"
    if ($securityAction -eq "BackupAndUpdate") {
        Backup-ConfigFile $SecurityConfigFile "codex-security.yaml"
    }
    if ($securityAction -ne "Skip") {
        [System.IO.File]::WriteAllText($SecurityConfigFile, $SecurityConfigContent, $Utf8NoBom)
        Write-Success "codex-security.yaml written (UTF-8 without BOM, no credentials)."
        $SecurityConfigured = $true
    } else {
        Write-WarningMsg "Skipped modifying codex-security.yaml as requested."
        $SecurityConfigured = Test-Path $SecurityConfigFile
    }

    # Select the file for plain 'codex-security scan' via a User environment variable. Never replace a different value silently.
    if ($SecurityConfigured) {
        $currentSelection = [System.Environment]::GetEnvironmentVariable('CODEX_SECURITY_PROJECT_CONFIG', 'User')
        if ([string]::IsNullOrWhiteSpace($currentSelection)) {
            [System.Environment]::SetEnvironmentVariable('CODEX_SECURITY_PROJECT_CONFIG', $SecurityConfigFile, 'User')
            $env:CODEX_SECURITY_PROJECT_CONFIG = $SecurityConfigFile
            Write-Success "Registered CODEX_SECURITY_PROJECT_CONFIG user environment variable -> $SecurityConfigFile"
        } elseif ($currentSelection -eq $SecurityConfigFile) {
            Write-Success "CODEX_SECURITY_PROJECT_CONFIG already points to $SecurityConfigFile."
        } else {
            Write-WarningMsg "CODEX_SECURITY_PROJECT_CONFIG already points somewhere else:"
            Write-Host "      current : $currentSelection" -ForegroundColor Yellow
            Write-Host "      proposed: $SecurityConfigFile" -ForegroundColor Cyan
            if (Ask-UserApproval "Replace the existing CODEX_SECURITY_PROJECT_CONFIG value with the ICA config?" $false) {
                [System.Environment]::SetEnvironmentVariable('CODEX_SECURITY_PROJECT_CONFIG', $SecurityConfigFile, 'User')
                $env:CODEX_SECURITY_PROJECT_CONFIG = $SecurityConfigFile
                Write-Success "CODEX_SECURITY_PROJECT_CONFIG updated."
            } else {
                Write-WarningMsg "Kept your existing CODEX_SECURITY_PROJECT_CONFIG. Use the ICA config explicitly with: codex-security scan . -c `"$SecurityConfigFile`""
            }
        }
    }
}


# ------------------------------------------------------------------------------
# STEP 6: Process Management (Terminate Stale Daemons with Confirmation)
# ------------------------------------------------------------------------------
if ($RunningDaemons.Count -gt 0) {
    Write-Step "Background Process Management..."
    $KillDaemons = Ask-UserApproval "Terminate $($RunningDaemons.Count) stale background Codex process(es) to reload environment?" $true
    if ($KillDaemons) {
        try {
            Get-Process -Name 'codex', 'node_repl' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-Success "Stopped background Codex daemons. They will restart automatically with fresh environment."
        } catch {
            Write-WarningMsg "Could not stop daemon processes: $_"
        }
    }
}

# ------------------------------------------------------------------------------
# STEP 7: Completion & Next Steps
# ------------------------------------------------------------------------------
Write-HeaderBox "IBM ICA + Codex Setup Completed Successfully!"

Write-Host "Configuration files:" -ForegroundColor Cyan
Write-Host " - Model Catalog:  $CatalogJsonFile" -ForegroundColor Gray
Write-Host " - Codex Config:   $ConfigFile" -ForegroundColor Gray
Write-Host " - API Key:        $EnvFile" -ForegroundColor Gray
if ($SecurityConfigured) {
    Write-Host " - Codex Security: $SecurityConfigFile" -ForegroundColor Gray
}
Write-Host " - Test Directory: $TestDir" -ForegroundColor Gray

Write-Host "`nNext Steps to Verify:" -ForegroundColor Yellow
Write-Host " 1. Reload environment in this current PowerShell window (run this command):" -ForegroundColor White
Write-Host "      `$env:ICA_API_KEY = [System.Environment]::GetEnvironmentVariable('ICA_API_KEY', 'User')" -ForegroundColor Cyan
Write-Host " 2. Open terminal in test folder and run Codex CLI:" -ForegroundColor White
Write-Host "      cd `"$TestDir`"" -ForegroundColor Cyan
Write-Host "      codex" -ForegroundColor Cyan
Write-Host "    Inside Codex, check status by typing:" -ForegroundColor White
Write-Host "      /status" -ForegroundColor Cyan
Write-Host "    (It should display: provider: ica, model: gpt-advantage-assist)" -ForegroundColor Gray
Write-Host " 3. For Visual Studio Code:" -ForegroundColor White
Write-Host "    - Install 'Codex - OpenAI''s coding agent' (OpenAI.chatgpt) extension." -ForegroundColor Gray
Write-Host "    - Open folder: `"$TestDir`" and click Trust." -ForegroundColor Gray
Write-Host "    - Open the Codex tab to start coding with ICA!" -ForegroundColor Gray
if ($SecurityConfigured) {
    Write-Host " 4. Codex Security (optional scanner) - open a NEW terminal first so CODEX_SECURITY_PROJECT_CONFIG is loaded:" -ForegroundColor White
    Write-Host "      codex-security scan . --dry-run" -ForegroundColor Cyan
    Write-Host "    NOTE: this only previews the ICA authentication/model selection. It is NOT a completed scan." -ForegroundColor Yellow
    Write-Host "    A real scan also needs the Codex Windows sandbox to start; on some machines it stops at" -ForegroundColor Yellow
    Write-Host "    'building threat model' (a separate, unresolved issue). See the README for details." -ForegroundColor Yellow
}
if (-not $HasChatGPTDesktop) {
    Write-Host " $(if ($SecurityConfigured) { 5 } else { 4 }). ChatGPT Desktop App (optional): install it manually (requires administrator privileges):" -ForegroundColor White
    Write-Host "    - https://chatgpt.com/download/ (only where approved by IBM policy)" -ForegroundColor Gray
}
Write-Host "=================================================================`n" -ForegroundColor Green
