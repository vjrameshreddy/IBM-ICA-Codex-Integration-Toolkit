<#
.SYNOPSIS
    Runs "codex-security scan" against IBM Consulting Advantage (ICA) instead of OpenAI.

.DESCRIPTION
    codex-security only reads OPENAI_API_KEY / CODEX_API_KEY / stored login by default, and
    ignores ICA_API_KEY. This wrapper passes the ICA provider settings (same values as
    ~/.codex/config.toml) so the scan authenticates with ICA_API_KEY and calls the ICA
    Responses API.

    - The key is read from the ICA_API_KEY environment variable only. It is never printed
      and never passed as an argument.
    - CODEX_CLI_PATH is pointed at your installed Codex (when found) for the duration of the
      scan only. The previous value is restored afterwards.
    - A scan sends repository content to the ICA endpoint. Use -DryRun to preview first.

.PARAMETER Repository
    Repository to scan. Default: current directory.

.PARAMETER Path
    One or more paths inside the repository to limit the scan (repeatable). Paths outside the
    repository are rejected; to scan another folder, pass it as -Repository instead.

.PARAMETER Diff
    Scan changes against a Git revision, for example origin/main.

.PARAMETER WorkingTree
    Scan uncommitted working-tree changes.

.PARAMETER Mode
    Scan mode passed to codex-security (default: standard).

.PARAMETER Model
    ICA model slug (default: gpt-advantage-assist). Must exist in ica-models.json.

.PARAMETER DryRun
    Validate inputs and show the resolved authentication without running a scan.

.PARAMETER CodexPath
    Explicit path to codex.exe. Default: existing CODEX_CLI_PATH, else "codex" on PATH.

.PARAMETER ExtraArgs
    Any further codex-security scan arguments, passed through unchanged.

.EXAMPLE
    .\codex-security-ica.ps1 -DryRun

.EXAMPLE
    .\codex-security-ica.ps1 . -Path src,tests

.EXAMPLE
    .\codex-security-ica.ps1 -Diff origin/main -Mode deep
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Repository = '.',

    [string[]]$Path,
    [string]$Diff,
    [switch]$WorkingTree,
    [string]$Mode = 'standard',
    [string]$Model = 'gpt-advantage-assist',
    [switch]$DryRun,
    [string]$CodexPath,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'

# ICA provider settings: keep in sync with the [model_providers.ica] block written by setup-codex-ica.ps1
$IcaBaseUrl = 'https://api.servicesessentials.ibm.com/v1'
$IcaEnvKey = 'ICA_API_KEY'

# --- Preflight ---------------------------------------------------------------
if (-not (Get-Command codex-security -ErrorAction SilentlyContinue)) {
    throw "codex-security is not installed. Run: npm install --global @openai/codex-security@latest"
}

# Prefer the current process value; fall back to the persisted User value (a terminal opened
# before the key was saved will not have it). Only the presence is checked, never printed.
$keyInProcess = [Environment]::GetEnvironmentVariable($IcaEnvKey, 'Process')
$keyFromUser = $null
if ([string]::IsNullOrWhiteSpace($keyInProcess)) {
    $keyFromUser = [Environment]::GetEnvironmentVariable($IcaEnvKey, 'User')
    if ([string]::IsNullOrWhiteSpace($keyFromUser)) {
        throw "$IcaEnvKey is not set. Run setup-codex-ica.ps1, then reopen the terminal (or set it for this session)."
    }
}

if (-not $CodexPath) {
    if ($env:CODEX_CLI_PATH) {
        $CodexPath = $env:CODEX_CLI_PATH
    } else {
        $cmd = Get-Command codex -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd) { $CodexPath = $cmd.Source }
    }
}
if ($CodexPath -and -not (Test-Path -LiteralPath $CodexPath)) {
    throw "CodexPath not found: $CodexPath"
}

# -Path only narrows a scan inside the repository. Catch the common mistake of passing the
# folder to scan as -Path (it then lands outside the default repository '.').
$repoFull = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine((Get-Location).ProviderPath, $Repository)).TrimEnd('\', '/')
foreach ($p in $Path) {
    if ($p -and [System.IO.Path]::IsPathRooted($p)) {
        $pFull = [System.IO.Path]::GetFullPath($p).TrimEnd('\', '/')
        $isInside = ($pFull -ieq $repoFull) -or $pFull.StartsWith($repoFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
        if (-not $isInside) {
            throw "-Path '$p' is outside the repository '$repoFull'. -Path only narrows a scan inside the repository. To scan that folder, pass it as the repository: .\codex-security-ica.ps1 '$p'"
        }
    }
}

# --- Build arguments ---------------------------------------------------------
# TOML values need embedded double quotes. Windows PowerShell 5.1 strips them when calling
# native commands, so they are escaped; PowerShell 7.3+ passes them correctly as-is.
$q = if ($PSVersionTable.PSVersion -ge [version]'7.3') { '"' } else { '\"' }
function ConvertTo-TomlArg([string]$Key, [string]$Value) { "$Key=$q$Value$q" }

$scanArgs = @('scan', $Repository)
foreach ($p in $Path) { if ($p) { $scanArgs += @('--path', $p) } }
if ($Diff) { $scanArgs += @('--diff', $Diff) }
if ($WorkingTree) { $scanArgs += '--working-tree' }
$scanArgs += @('--mode', $Mode, '--auth', 'api-key', '--model', $Model)
$scanArgs += @('--codex', (ConvertTo-TomlArg 'model_provider' 'ica'))
$scanArgs += @('--codex', (ConvertTo-TomlArg 'model_providers.ica.name' 'ICA'))
$scanArgs += @('--codex', (ConvertTo-TomlArg 'model_providers.ica.base_url' $IcaBaseUrl))
$scanArgs += @('--codex', (ConvertTo-TomlArg 'model_providers.ica.wire_api' 'responses'))
$scanArgs += @('--codex', (ConvertTo-TomlArg 'model_providers.ica.env_key' $IcaEnvKey))
if ($DryRun) { $scanArgs += '--dry-run' }
if ($ExtraArgs) { $scanArgs += $ExtraArgs }

# --- Run (environment changes are scoped to this invocation) ------------------
$savedCliPath = $env:CODEX_CLI_PATH
$savedKey = $keyInProcess
try {
    if ($CodexPath) { $env:CODEX_CLI_PATH = $CodexPath }
    if ($keyFromUser) { [Environment]::SetEnvironmentVariable($IcaEnvKey, $keyFromUser, 'Process') }

    if (-not $DryRun) {
        Write-Host "[INFO] Scanning '$Repository' with ICA model '$Model'. Repository content is sent to $IcaBaseUrl." -ForegroundColor Cyan
    }

    # codex-security writes progress to stderr, so do not redirect it or stop on it.
    $ErrorActionPreference = 'Continue'
    & codex-security @scanArgs
    $exit = $LASTEXITCODE
}
finally {
    $env:CODEX_CLI_PATH = $savedCliPath
    if ($keyFromUser) { [Environment]::SetEnvironmentVariable($IcaEnvKey, $savedKey, 'Process') }
}

exit $exit
