<#
.SYNOPSIS
    Runs "codex-security scan" against IBM Consulting Advantage (ICA) instead of OpenAI.

.DESCRIPTION
    codex-security uses its own Codex home and does not inherit the provider from
    ~/.codex/config.toml, so by default it falls back to stored credentials / OpenAI sign-in.
    This wrapper selects ICA so the scan authenticates with ICA_API_KEY and calls the ICA
    Responses API:

    - If ~/.codex/codex-security.yaml exists (written by setup-codex-ica), it is reused with
      "-c". Otherwise the same ICA provider settings are passed as explicit --codex overrides.
      Either way, auto authentication and "--auth api-key" both resolve to ICA_API_KEY.
    - The key is read from the ICA_API_KEY environment variable only. It is never printed
      and never passed as an argument.
    - CODEX_CLI_PATH is pointed at your installed Codex (when found) for the duration of the
      scan only. The previous value is restored afterwards.
    - A scan sends repository content to the ICA endpoint. Use -DryRun to preview first.

    IMPORTANT: selecting ICA authentication does not guarantee that a scan completes. Codex
    must also start its Windows sandbox, which is a separate problem; on some machines scans
    stop at "building threat model". -DryRun only previews authentication and model selection
    and is never proof that a scan will complete.

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

.PARAMETER ConfigPath
    Codex Security project config to use. Default: ~/.codex/codex-security.yaml when it exists,
    otherwise explicit --codex ICA overrides. CODEX_SECURITY_PROJECT_CONFIG is not followed
    automatically, because it may point to a non-ICA configuration.

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
    [string]$ConfigPath,
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

# Reuse the project config written by setup-codex-ica when present; otherwise fall back to overrides.
if (-not $ConfigPath) {
    $defaultConfig = Join-Path (Join-Path $HOME '.codex') 'codex-security.yaml'
    if (Test-Path -LiteralPath $defaultConfig) { $ConfigPath = $defaultConfig }
}
if ($ConfigPath -and -not (Test-Path -LiteralPath $ConfigPath)) {
    throw "ConfigPath not found: $ConfigPath"
}

$scanArgs = @('scan', $Repository)
foreach ($p in $Path) { if ($p) { $scanArgs += @('--path', $p) } }
if ($Diff) { $scanArgs += @('--diff', $Diff) }
if ($WorkingTree) { $scanArgs += '--working-tree' }
$scanArgs += @('--mode', $Mode)
if ($ConfigPath) {
    $scanArgs += @('-c', $ConfigPath)
    # The file already selects the ICA provider, model and api-key auth; only override the model on request.
    if ($PSBoundParameters.ContainsKey('Model')) { $scanArgs += @('--model', $Model) }
    $configSource = "project config $ConfigPath"
} else {
    $scanArgs += @('--auth', 'api-key', '--model', $Model)
    $scanArgs += @('--codex', (ConvertTo-TomlArg 'model_provider' 'ica'))
    $scanArgs += @('--codex', (ConvertTo-TomlArg 'model_providers.ica.name' 'ICA'))
    $scanArgs += @('--codex', (ConvertTo-TomlArg 'model_providers.ica.base_url' $IcaBaseUrl))
    $scanArgs += @('--codex', (ConvertTo-TomlArg 'model_providers.ica.wire_api' 'responses'))
    $scanArgs += @('--codex', (ConvertTo-TomlArg 'model_providers.ica.env_key' $IcaEnvKey))
    $configSource = 'explicit --codex ICA overrides (no ~/.codex/codex-security.yaml found)'
}
if ($DryRun) { $scanArgs += '--dry-run' }
if ($ExtraArgs) { $scanArgs += $ExtraArgs }

# --- Run (environment changes are scoped to this invocation) ------------------
$savedCliPath = $env:CODEX_CLI_PATH
$savedKey = $keyInProcess
try {
    if ($CodexPath) { $env:CODEX_CLI_PATH = $CodexPath }
    if ($keyFromUser) { [Environment]::SetEnvironmentVariable($IcaEnvKey, $keyFromUser, 'Process') }

    Write-Host "[INFO] ICA selection via $configSource." -ForegroundColor DarkGray
    if (-not $DryRun) {
        Write-Host "[INFO] Scanning '$Repository' with ICA. Repository content is sent to $IcaBaseUrl." -ForegroundColor Cyan
    }

    # codex-security writes progress to stderr, so do not redirect it or stop on it.
    $ErrorActionPreference = 'Continue'
    & codex-security @scanArgs
    $exit = $LASTEXITCODE

    if ($DryRun) {
        Write-Host "[DRY-RUN] Preview only: this shows the resolved ICA authentication and model, not a completed scan. Sandbox startup is not tested." -ForegroundColor Yellow
    } elseif ($exit -ne 0) {
        Write-Host "[NOTE] ICA authentication being selected does not guarantee the scan completes. If the error mentions the Windows sandbox, that is a separate problem from authentication (see the README)." -ForegroundColor Yellow
    }
}
finally {
    $env:CODEX_CLI_PATH = $savedCliPath
    if ($keyFromUser) { [Environment]::SetEnvironmentVariable($IcaEnvKey, $savedKey, 'Process') }
}

exit $exit
