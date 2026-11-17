param(
    [Alias("Preview", "Plan")]
    [switch]$DryRun,

    [Alias("AssumeYes")]
    [switch]$Yes,

    [switch]$KeepConfig,
    [switch]$KeepApiKey,
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

# -Explicit prompts (software that may predate the setup) are never auto-approved by -Yes / -NonInteractive.
function Ask-UserApproval {
    param([string]$PromptText, [bool]$DefaultYes = $false, [switch]$Explicit)

    if ($Explicit -and ($Yes -or $NonInteractive)) {
        return $false
    }

    if ($Yes -or $NonInteractive) {
        return $true
    }

    $options = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    $response = Read-Host "$PromptText $options"

    if ([string]::IsNullOrWhiteSpace($response)) {
        return $DefaultYes
    }

    return ($response.Trim().ToLower() -eq 'y' -or $response.Trim().ToLower() -eq 'yes')
}

# Restrict a directory (and its contents) to the current user; the backup may contain ICA_API_KEY.
# Only the directory itself is changed (no /T): its inheritable owner-only ACE propagates to children,
# whereas /T would strip inheritance from the files and leave them with no ACEs at all.
function Restrict-ToOwner {
    param([string]$Path)
    try {
        & icacls $Path /inheritance:r /grant:r "$($env:USERNAME):(OI)(CI)F" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-WarningMsg "Could not restrict permissions on $Path (icacls exit code $LASTEXITCODE)." }
    } catch {
        Write-WarningMsg "Could not restrict permissions on $Path`: $_"
    }
}

Clear-Host
Write-HeaderBox "IBM ICA + Codex Automated Uninstaller & Cleanup Tool" "Windows Edition with Safe Cleanup & Confirmation"

# 1. Environment & State Inspection
$CodexDir = Join-Path $HOME ".codex"
$TestDir = Join-Path $HOME "codex-ica-test"

# Prerequisites the setup script can install via winget (keep in sync with setup-codex-ica.ps1)
$WingetPackages = [ordered]@{
    "Git"        = "Git.Git"
    "GitHub CLI" = "GitHub.cli"
    "Node.js"    = "OpenJS.NodeJS.LTS"
    "Python"     = "Python.Python.3.14"
}

Write-Step "Inspecting current Codex installation state..."

$RunningDaemons = @()
try {
    $RunningDaemons = Get-Process -Name 'codex', 'node_repl' -ErrorAction SilentlyContinue
} catch {}

$CodexCliInstalled = $false
try {
    $cOut = Invoke-Expression "codex --version" 2>$null
    if ($LASTEXITCODE -eq 0 -and $cOut) { $CodexCliInstalled = $true }
} catch {}

$CodexSecurityInstalled = $false
try {
    $sOut = Invoke-Expression "codex-security --version" 2>$null
    if ($LASTEXITCODE -eq 0 -and $sOut) { $CodexSecurityInstalled = $true }
} catch {}

$InstalledPackages = @()
if ($CodexCliInstalled) { $InstalledPackages += "@openai/codex" }
if ($CodexSecurityInstalled) { $InstalledPackages += "@openai/codex-security" }

$HasCodexDir = Test-Path $CodexDir

$UserApiKey = [System.Environment]::GetEnvironmentVariable('ICA_API_KEY', 'User')
$UserSecurityConfig = [System.Environment]::GetEnvironmentVariable('CODEX_SECURITY_PROJECT_CONFIG', 'User')
$EnvVarsFound = @()
if (-not [string]::IsNullOrWhiteSpace($UserApiKey)) { $EnvVarsFound += "ICA_API_KEY" }
if (-not [string]::IsNullOrWhiteSpace($UserSecurityConfig)) { $EnvVarsFound += "CODEX_SECURITY_PROJECT_CONFIG" }

$HasTestDir = Test-Path $TestDir

# Prerequisites currently installed through winget (read-only query)
$HasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
$InstalledPrereqs = @()
if ($HasWinget) {
    foreach ($Tool in $WingetPackages.Keys) {
        $PackageId = $WingetPackages[$Tool]
        try {
            & winget list --id $PackageId -e --accept-source-agreements *> $null
            if ($LASTEXITCODE -eq 0) { $InstalledPrereqs += $Tool }
        } catch {}
    }
}

if ($RunningDaemons.Count -gt 0) {
    Write-Host " [INFO] Running Daemons        : $($RunningDaemons.Count) active process(es) ($(($RunningDaemons | Select-Object -ExpandProperty ProcessName -Unique) -join ', '))" -ForegroundColor Yellow
} else {
    Write-Host " [INFO] Running Daemons        : None detected" -ForegroundColor DarkGray
}

if ($InstalledPackages.Count -gt 0) {
    Write-Host " [INFO] Global npm Packages    : $($InstalledPackages -join ', ')" -ForegroundColor Yellow
} else {
    Write-Host " [INFO] Global npm Packages    : None detected" -ForegroundColor DarkGray
}

if ($HasCodexDir) {
    Write-Host " [INFO] Configuration Directory: $CodexDir (Exists)" -ForegroundColor Yellow
} else {
    Write-Host " [INFO] Configuration Directory: $CodexDir (Not present)" -ForegroundColor DarkGray
}

if ($EnvVarsFound.Count -gt 0) {
    Write-Host " [INFO] User Environment Vars  : $($EnvVarsFound -join ', ')" -ForegroundColor Yellow
} else {
    Write-Host " [INFO] User Environment Vars  : None found" -ForegroundColor DarkGray
}

if ($HasTestDir) {
    Write-Host " [INFO] Test Workspace Folder  : $TestDir (Exists)" -ForegroundColor Yellow
} else {
    Write-Host " [INFO] Test Workspace Folder  : $TestDir (Not present)" -ForegroundColor DarkGray
}

if (-not $HasWinget) {
    Write-Host " [INFO] Prerequisites (winget) : winget not available" -ForegroundColor DarkGray
} elseif ($InstalledPrereqs.Count -gt 0) {
    Write-Host " [INFO] Prerequisites (winget) : $($InstalledPrereqs -join ', ')" -ForegroundColor Yellow
} else {
    Write-Host " [INFO] Prerequisites (winget) : None installed via winget" -ForegroundColor DarkGray
}

# 2. Preview / Dry-Run Plan
Write-Host "`n+---------------------------------------------------------------+" -ForegroundColor Yellow
Write-Host "|                 UNINSTALL ACTIONS PREVIEW                     |" -ForegroundColor Yellow
Write-Host "+---------------------------------------------------------------+" -ForegroundColor Yellow
Write-Host " Each item below is confirmed individually before it is removed." -ForegroundColor Gray

if ($RunningDaemons.Count -gt 0) {
    Write-Host " 1. Daemons     : Terminate $($RunningDaemons.Count) running codex/node_repl process(es)" -ForegroundColor White
} else {
    Write-Host " 1. Daemons     : No running daemons to terminate" -ForegroundColor Gray
}

if ($InstalledPackages.Count -gt 0) {
    Write-Host " 2. npm Packages: Uninstall global npm package(s): $($InstalledPackages -join ', ')" -ForegroundColor White
} else {
    Write-Host " 2. npm Packages: No global npm packages to uninstall" -ForegroundColor Gray
}

if ($KeepConfig) {
    Write-Host " 3. Config/State: Keep $CodexDir (-KeepConfig switch specified)" -ForegroundColor Gray
} elseif ($HasCodexDir) {
    Write-Host " 3. Config/State: Remove $CodexDir (will offer final owner-only backup first)" -ForegroundColor White
} else {
    Write-Host " 3. Config/State: No configuration directory found" -ForegroundColor Gray
}

if ($KeepApiKey) {
    Write-Host " 4. Environment : Keep User environment variables (-KeepApiKey switch specified)" -ForegroundColor Gray
} elseif ($EnvVarsFound.Count -gt 0) {
    Write-Host " 4. Environment : Remove User environment variables: $($EnvVarsFound -join ', ')" -ForegroundColor White
} else {
    Write-Host " 4. Environment : No Codex User environment variables found" -ForegroundColor Gray
}

if ($HasTestDir) {
    Write-Host " 5. Test Folder : Offer to remove test workspace $TestDir" -ForegroundColor White
} else {
    Write-Host " 5. Test Folder : No test workspace found" -ForegroundColor Gray
}

if ($InstalledPrereqs.Count -gt 0) {
    Write-Host " 6. Prerequisites: Offer to uninstall via winget (default No, never auto-approved): $($InstalledPrereqs -join ', ')" -ForegroundColor White
    Write-Host "                   Other software may depend on these tools." -ForegroundColor DarkYellow
} else {
    Write-Host " 6. Prerequisites: No winget-installed prerequisites found" -ForegroundColor Gray
}

Write-Host "+---------------------------------------------------------------+`n" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host "[DRY-RUN] No changes were made to your system. To execute uninstallation, run without -DryRun." -ForegroundColor Green
    exit 0
}

# 3. Explicit User Confirmation (Defaults to No)
$Proceed = Ask-UserApproval "Are you sure you want to proceed with uninstallation and cleanup?" $false
if (-not $Proceed) {
    Write-WarningMsg "Uninstallation cancelled by user. No files or settings were modified."
    exit 0
}

# 4. Stop Daemons
if ($RunningDaemons.Count -gt 0) {
    if (Ask-UserApproval "Stop $($RunningDaemons.Count) running codex/node_repl process(es)?" $true) {
        Write-Step "Stopping background daemons..."
        try {
            Stop-Process -Name 'codex', 'node_repl' -Force -ErrorAction SilentlyContinue
            Write-Success "Terminated background daemons."
        } catch {
            Write-WarningMsg "Could not stop all daemons: $_"
        }
    } else {
        Write-Host " [INFO] Left background daemons running." -ForegroundColor DarkGray
    }
}

# 5. Uninstall Global npm Packages (before Node.js, which provides npm, may be removed)
foreach ($pkg in $InstalledPackages) {
    if (Ask-UserApproval "Uninstall global npm package $pkg?" $true) {
        Write-Step "Uninstalling $pkg..."
        Write-Host "Running: npm uninstall -g $pkg" -ForegroundColor DarkCyan
        try {
            & npm uninstall -g $pkg
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Uninstalled $pkg"
            } else {
                Write-WarningMsg "npm uninstall failed for $pkg (exit code $LASTEXITCODE)."
            }
        } catch {
            Write-WarningMsg "Error uninstalling $pkg`: $_"
        }
    } else {
        Write-Host " [INFO] Kept $pkg" -ForegroundColor DarkGray
    }
}

# 6. Cleanup ~/.codex
if (-not $KeepConfig -and $HasCodexDir) {
    if (Ask-UserApproval "Remove Codex configuration directory $CodexDir (config.toml, model catalog, .env)?" $true) {
        Write-Step "Cleaning up Codex configuration directory ($CodexDir)..."
        $makeBackup = Ask-UserApproval "Create a final timestamped backup of $CodexDir before deleting?" $true
        if ($makeBackup) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $bakDir = "$CodexDir.bak.$timestamp"
            try {
                Copy-Item -Path $CodexDir -Destination $bakDir -Recurse -Force
                # The backup can contain .env with ICA_API_KEY: restrict to the current user immediately.
                Restrict-ToOwner $bakDir
                Write-Success "Backup created (owner-only) -> $bakDir"
            } catch {
                Write-WarningMsg "Could not backup $CodexDir`: $_"
            }
        }
        try {
            Remove-Item -Path $CodexDir -Recurse -Force
            Write-Success "Removed $CodexDir"
        } catch {
            Write-WarningMsg "Could not completely remove $CodexDir`: $_"
        }
    } else {
        Write-Host " [INFO] Kept $CodexDir" -ForegroundColor DarkGray
    }
}

# 7. Cleanup User Environment Variables
if (-not $KeepApiKey -and $EnvVarsFound.Count -gt 0) {
    Write-Step "Cleaning up User environment variables..."
    foreach ($VarName in $EnvVarsFound) {
        if (Ask-UserApproval "Remove User environment variable $VarName?" $true) {
            [System.Environment]::SetEnvironmentVariable($VarName, $null, 'User')
            Write-Success "Removed User environment variable: $VarName"
        } else {
            Write-Host " [INFO] Kept User environment variable: $VarName" -ForegroundColor DarkGray
        }
    }
}

# 8. Cleanup Test Workspace (Optional)
if ($HasTestDir) {
    if (Ask-UserApproval "Remove test workspace directory ($TestDir)?" $false) {
        try {
            Remove-Item -Path $TestDir -Recurse -Force
            Write-Success "Removed test workspace: $TestDir"
        } catch {
            Write-WarningMsg "Could not remove $TestDir`: $_"
        }
    } else {
        Write-Host " [INFO] Preserved test workspace directory: $TestDir" -ForegroundColor DarkGray
    }
}

# 9. Prerequisites installed by the setup via winget (explicit interactive confirmation only)
if ($InstalledPrereqs.Count -gt 0) {
    Write-Step "Prerequisites installed via winget..."
    if ($Yes -or $NonInteractive) {
        Write-Host " [INFO] Skipped: prerequisite removal requires interactive confirmation (-Yes / -NonInteractive never approve it)." -ForegroundColor DarkGray
    } else {
        Write-WarningMsg "These tools may have been installed before this setup, and other software may depend on them."
        foreach ($Tool in $InstalledPrereqs) {
            $PackageId = $WingetPackages[$Tool]
            if (Ask-UserApproval "Uninstall $Tool ($PackageId) via winget?" $false -Explicit) {
                Write-Host "Running: winget uninstall --id $PackageId -e" -ForegroundColor DarkCyan
                try {
                    & winget uninstall --id $PackageId -e --accept-source-agreements
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Uninstalled $Tool"
                    } else {
                        Write-WarningMsg "winget could not uninstall $Tool (exit code $LASTEXITCODE)."
                    }
                } catch {
                    Write-WarningMsg "Could not invoke winget for ${Tool}: $_"
                }
            } else {
                Write-Host " [INFO] Kept $Tool" -ForegroundColor DarkGray
            }
        }
    }
}

Write-HeaderBox "Uninstallation Complete" "Items you approved were removed; everything else was left untouched."
exit 0
