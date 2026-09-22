[CmdletBinding()]
param(
    [ValidateSet('quick', 'full', 'browser', 'development')]
    [string] $Scope = 'development'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repoRoot = Split-Path -Parent $PSScriptRoot
$failureCount = 0
. (Join-Path $PSScriptRoot 'tooling.ps1')

function Write-Check {
    param(
        [ValidateSet('PASS', 'FAIL', 'WARN', 'INFO')][string] $Status,
        [string] $Message
    )
    if ($Status -eq 'FAIL') { $script:failureCount++ }
    Write-Host "[$Status] $Message"
}

function Find-Tool {
    param([string] $Name)
    $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command.Path) { return $command.Path }
    return $command.Source
}

function Read-Version {
    param([string] $Command, [string[]] $Arguments = @('--version'))
    try {
        $global:LASTEXITCODE = 0
        $output = & $Command @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) { return $null }
        return ($output | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ } | Select-Object -First 1)
    }
    catch { return $null }
}

function Test-Tool {
    param(
        [string] $Label,
        [string] $CommandName,
        [string] $Required,
        [string] $VersionPattern,
        [string[]] $Arguments = @('--version')
    )
    $command = Find-Tool $CommandName
    if (-not $command) {
        Write-Check FAIL "$Label is missing. $Required"
        return
    }
    $version = Read-Version $command $Arguments
    if (-not $version) {
        Write-Check FAIL "$Label was found at '$command' but did not report a version. $Required"
    }
    elseif ($VersionPattern -and $version -notmatch $VersionPattern) {
        Write-Check FAIL "$Label $version is unsupported. $Required"
    }
    else { Write-Check PASS "$Label $version" }
}

function Test-DotNetSdk {
    try { $globalJson = Get-Content -Raw (Join-Path $repoRoot 'global.json') | ConvertFrom-Json }
    catch {
        Write-Check FAIL 'Cannot read global.json. Restore a valid repository copy.'
        return
    }
    $expected = [string]$globalJson.sdk.version
    if (-not $expected) {
        Write-Check FAIL 'global.json does not declare an SDK version.'
        return
    }
    if ($globalJson.sdk.rollForward -ne 'disable' -or $globalJson.sdk.allowPrerelease -ne $false) {
        Write-Check FAIL "global.json must pin SDK $expected with rollForward=disable and allowPrerelease=false."
    }
    else { Write-Check INFO "Declared .NET SDK: $expected (exact)" }

    $dotnet = Find-Tool dotnet
    if (-not $dotnet) {
        Write-Check FAIL "The .NET SDK is missing. Install SDK $expected from https://dotnet.microsoft.com/download/dotnet/10.0."
        return
    }
    Push-Location $repoRoot
    try { $selected = Read-Version $dotnet }
    finally { Pop-Location }
    if ($selected -eq $expected) { Write-Check PASS ".NET SDK $selected selected by global.json" }
    elseif ($selected) { Write-Check FAIL ".NET SDK $selected is selected. Install the required SDK $expected." }
    else { Write-Check FAIL "SDK $expected is not selectable. Install that exact SDK." }
}

function Test-Bash {
    $bash = Resolve-CheckBash -AllowMissing
    if (-not $bash) {
        $remedy = if ($IsWindows) { 'Install Git for Windows; the WSL bash launcher is not used.' } else { 'Install Bash and add it to PATH.' }
        Write-Check FAIL "Bash is missing. $remedy"
        return
    }
    $version = Read-Version $bash
    if ($version) { Write-Check PASS "Bash: $version ($bash)" }
    else { Write-Check FAIL "Bash was found at '$bash' but did not report a version." }
}

function Test-DockerCompose {
    $docker = Find-Tool docker
    if (-not $docker) {
        Write-Check FAIL 'Docker CLI is missing. Install a Docker CLI with the Compose plugin; a running daemon is not required.'
        return
    }
    $dockerVersion = Read-Version $docker
    $composeVersion = Read-Version $docker @('compose', 'version')
    if ($dockerVersion) { Write-Check PASS $dockerVersion }
    else { Write-Check FAIL "Docker at '$docker' did not report a CLI version." }
    if ($composeVersion) { Write-Check PASS $composeVersion }
    else { Write-Check FAIL 'Docker Compose is unavailable. Install the Compose CLI plugin; no daemon is required.' }
}

function Test-Aspire {
    $aspire = Find-Tool aspire
    if (-not $aspire) {
        Write-Check FAIL "Aspire CLI is missing. Run 'dotnet tool install --global Aspire.Cli --version 13.4.2', then reopen the terminal."
        return
    }
    $version = Read-Version $aspire
    if ($version -match '^13\.4\.2(?:\+|$)') { Write-Check PASS "Aspire CLI $version" }
    elseif ($version) { Write-Check FAIL "Aspire CLI $version is installed; install version 13.4.2." }
    else { Write-Check FAIL "Aspire at '$aspire' did not report a version; install version 13.4.2." }
}

function Show-ManifestPins {
    param([switch] $RequirePlaywright)
    try {
        $tools = Get-Content -Raw (Join-Path $repoRoot '.config/dotnet-tools.json') | ConvertFrom-Json
        $husky = [string]$tools.tools.husky.version
        if ($husky) { Write-Check INFO "Husky manifest pin: $husky (opt-in; not restored by doctor)" }
        else { Write-Check WARN 'The Husky pin is missing from .config/dotnet-tools.json.' }
    }
    catch { Write-Check WARN 'Cannot read the Husky pin from .config/dotnet-tools.json.' }

    try {
        $package = Get-Content -Raw (Join-Path $repoRoot 'tests/deploy-smoke/package.json') | ConvertFrom-Json
        $lock = Get-Content -Raw (Join-Path $repoRoot 'tests/deploy-smoke/package-lock.json') | ConvertFrom-Json -AsHashtable
        $pin = [string]$package.devDependencies.playwright
        $lockedPin = [string]$lock['packages']['']['devDependencies']['playwright']
        $lockedVersion = [string]$lock['packages']['node_modules/playwright']['version']
        if ($pin -match '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$' -and $pin -eq $lockedPin -and $pin -eq $lockedVersion) {
            Write-Check INFO "Playwright manifest pin: $pin (not installed or restored by doctor)"
        }
        else {
            Write-Check $(if ($RequirePlaywright) { 'FAIL' } else { 'WARN' }) 'The Playwright manifest and lockfile need one matching exact version.'
        }
    }
    catch { Write-Check $(if ($RequirePlaywright) { 'FAIL' } else { 'WARN' }) 'Cannot read the Playwright pins from tests/deploy-smoke.' }
}

Write-Host "OpenGameBuilder doctor (scope: $Scope)"
$powerShellVersion = $PSVersionTable.PSVersion.ToString()
if ($PSVersionTable.PSVersion.Major -ge 7) { Write-Check PASS "PowerShell $powerShellVersion" }
else { Write-Check FAIL "PowerShell $powerShellVersion is unsupported. Install PowerShell 7 and rerun with pwsh." }
Show-ManifestPins -RequirePlaywright:($Scope -in @('full', 'browser'))

if ($Scope -in @('quick', 'full', 'development')) { Test-DotNetSdk }
if ($Scope -in @('full', 'development')) {
    Test-Tool 'Git' 'git' 'Install Git (Git for Windows on Windows).' '^git version '
    Test-Bash
}
if ($Scope -in @('full', 'browser')) {
    Test-Tool 'Node.js' 'node' 'Install Node.js 22.' '^v?22(?:\.|$)'
    Test-Tool 'npm' 'npm' 'Install npm with Node.js 22.' '^\d+\.'
}
if ($Scope -eq 'full') { Test-DockerCompose }
if ($Scope -eq 'development') { Test-Aspire }

if ($failureCount -gt 0) {
    Write-Host "Doctor found $failureCount required prerequisite problem(s)."
    exit 1
}
Write-Host 'All required prerequisites for this scope are available.'
