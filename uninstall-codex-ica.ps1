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

function Ask-UserApproval {
    param([string]$PromptText, [bool]$DefaultYes = $false)
    
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

Clear-Host
Write-HeaderBox "IBM ICA + Codex Automated Uninstaller & Cleanup Tool" "Windows Edition with Safe Cleanup & Confirmation"

# 1. Environment & State Inspection
$CodexDir = Join-Path $HOME ".codex"
$TestDir = Join-Path $HOME "IBM ICA-Codex-Integration-Toolkit"

Write-Step "Inspecting current Codex installation state..."

$RunningDaemons = @()
try {
    $RunningDaemons = Get-Process -Name 'codex', 'node_repl' -ErrorAction SilentlyContinue
} catch {}

if ($RunningDaemons.Count -gt 0) {
    Write-Host " [INFO] Running Daemons        : $($RunningDaemons.Count) active process(es) ($(($RunningDaemons | Select-Object -ExpandProperty ProcessName -Unique) -join ', '))" -ForegroundColor Yellow
} else {
    Write-Host " [INFO] Running Daemons        : None detected" -ForegroundColor DarkGray
}

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

if ($InstalledPackages.Count -gt 0) {
    Write-Host " [INFO] Global npm Packages    : $($InstalledPackages -join ', ')" -ForegroundColor Yellow
} else {
    Write-Host " [INFO] Global npm Packages    : None detected" -ForegroundColor DarkGray
}

$HasCodexDir = Test-Path $CodexDir
if ($HasCodexDir) {
    Write-Host " [INFO] Configuration Directory: $CodexDir (Exists)" -ForegroundColor Yellow
} else {
    Write-Host " [INFO] Configuration Directory: $CodexDir (Not present)" -ForegroundColor DarkGray
}

$UserApiKey = [System.Environment]::GetEnvironmentVariable('ICA_API_KEY', 'User')
$UserSecurityConfig = [System.Environment]::GetEnvironmentVariable('CODEX_SECURITY_PROJECT_CONFIG', 'User')
$EnvVarsFound = @()
if (-not [string]::IsNullOrWhiteSpace($UserApiKey)) { $EnvVarsFound += "ICA_API_KEY" }
if (-not [string]::IsNullOrWhiteSpace($UserSecurityConfig)) { $EnvVarsFound += "CODEX_SECURITY_PROJECT_CONFIG" }

if ($EnvVarsFound.Count -gt 0) {
    Write-Host " [INFO] User Environment Vars  : $($EnvVarsFound -join ', ')" -ForegroundColor Yellow
} else {
    Write-Host " [INFO] User Environment Vars  : None found" -ForegroundColor DarkGray
}

$HasTestDir = Test-Path $TestDir
if ($HasTestDir) {
    Write-Host " [INFO] Test Workspace Folder  : $TestDir (Exists)" -ForegroundColor Yellow
} else {
    Write-Host " [INFO] Test Workspace Folder  : $TestDir (Not present)" -ForegroundColor DarkGray
}

# 2. Preview / Dry-Run Plan
Write-Host "`n+---------------------------------------------------------------+" -ForegroundColor Yellow
Write-Host "|                 UNINSTALL ACTIONS PREVIEW                     |" -ForegroundColor Yellow
Write-Host "+---------------------------------------------------------------+" -ForegroundColor Yellow

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
    Write-Host " 3. Config/State: Remove $CodexDir (will offer final backup first)" -ForegroundColor White
} else {
    Write-Host " 3. Config/State: No configuration directory found" -ForegroundColor Gray
}

if ($KeepApiKey) {
    Write-Host " 4. Environment : Keep ICA_API_KEY User environment variable (-KeepApiKey switch specified)" -ForegroundColor Gray
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
    Write-Step "Stopping background daemons..."
    try {
        Stop-Process -Name 'codex', 'node_repl' -Force -ErrorAction SilentlyContinue
        Write-Success "Terminated background daemons."
    } catch {
        Write-WarningMsg "Could not stop all daemons: $_"
    }
}

# 5. Uninstall Global npm Packages
if ($InstalledPackages.Count -gt 0) {
    Write-Step "Uninstalling global npm packages..."
    foreach ($pkg in $InstalledPackages) {
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
    }
}

# 6. Cleanup ~/.codex
if (-not $KeepConfig -and $HasCodexDir) {
    Write-Step "Cleaning up Codex configuration directory ($CodexDir)..."
    $makeBackup = Ask-UserApproval "Create a final timestamped backup of $CodexDir before deleting?" $true
    if ($makeBackup) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $bakDir = "$CodexDir.bak.$timestamp"
        try {
            Copy-Item -Path $CodexDir -Destination $bakDir -Recurse -Force
            Write-Success "Backup created -> $bakDir"
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
}

# 7. Cleanup User Environment Variables
if (-not $KeepApiKey) {
    Write-Step "Cleaning up User environment variables..."
    if (-not [string]::IsNullOrWhiteSpace($UserApiKey)) {
        [System.Environment]::SetEnvironmentVariable('ICA_API_KEY', $null, 'User')
        Write-Success "Removed User environment variable: ICA_API_KEY"
    }
    if (-not [string]::IsNullOrWhiteSpace($UserSecurityConfig)) {
        [System.Environment]::SetEnvironmentVariable('CODEX_SECURITY_PROJECT_CONFIG', $null, 'User')
        Write-Success "Removed User environment variable: CODEX_SECURITY_PROJECT_CONFIG"
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

Write-HeaderBox "Uninstallation Complete" "Your system is clean and ready for a fresh setup."
exit 0
