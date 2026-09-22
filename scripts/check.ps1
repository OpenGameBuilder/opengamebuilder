#Requires -Version 7.0
<#
.SYNOPSIS
Runs the same validation locally and in CI; see docs/quality/testing.md.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('format', 'content', 'external-links', 'quick', 'full', 'browser')]
    [string] $Mode = 'quick',
    [switch] $Fix,
    [switch] $Serial,
    [switch] $SkipWebPublish
)

$ErrorActionPreference = 'Stop'
# Capture native failures ourselves so their output is retained in the step log.
$PSNativeCommandUseErrorActionPreference = $false
if ($Fix -and $Mode -ne 'format') { throw '-Fix is only valid with format.' }
if ($SkipWebPublish -and $Mode -ne 'full') { throw '-SkipWebPublish is only valid with full.' }

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
    New-Item -ItemType Directory -Force artifacts/validation | Out-Null
    @(
        "Operating system: $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)"
        "OS architecture: $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)"
        if ($env:ImageOS) { "Runner image: $env:ImageOS $env:ImageVersion" }
        "Check mode: $Mode; serial MSBuild: $Serial"
    ) | Tee-Object -FilePath artifacts/validation/environment.log | Write-Host

    function Invoke-Check {
        param([string] $Name, [string] $Command, [string[]] $Arguments)
        Write-Host "Checking $Name"
        & $Command @Arguments 2>&1 | Tee-Object -FilePath "artifacts/validation/$Name.log"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Check stopped. Details: artifacts/validation/$Name.log."
            exit $LASTEXITCODE
        }
    }

    if ($Mode -eq 'full') {
        if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
            throw 'Node.js is missing. Install the recommended version from .node-version, then restart your terminal or editor.'
        }
        Invoke-Check 'node-policy' 'node' @('scripts/check-node.mjs')
        $npm = if ($IsWindows) { 'npm.cmd' } else { 'npm' }
        Invoke-Check 'content-dependencies' $npm @('ci', '--ignore-scripts')
    }
    $scope = if ($Mode -eq 'external-links') { 'content' } else { $Mode }
    Invoke-Check 'doctor' (Join-Path $PSHOME $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' })) @(
        '-NoProfile', '-File', "$PSScriptRoot/doctor.ps1", '-Scope', $scope
    )

    if ($Mode -in @('content', 'external-links', 'full', 'format')) {
        $contentMode = switch ($Mode) {
            'external-links' { 'external-links' }
            'format' { 'format' }
            default { 'all' }
        }
        $contentArguments = @('scripts/check-content.mjs', $contentMode)
        if ($Fix) { $contentArguments += '--fix' }
        Invoke-Check 'content' 'node' $contentArguments
        if ($Mode -eq 'full') {
            Invoke-Check 'content-regressions' 'node' @('--test', 'tests/content-checks/check.test.mjs')
            Invoke-Check 'ai-tooling-regressions' 'node' @('--test', 'tests/ai-tooling/check.test.mjs')
            Invoke-Check 'ci-policy-regressions' 'node' @('--test', 'tests/ci-policy/check.test.mjs')
            Invoke-Check 'contributor-regressions' 'node' @('--test', 'tests/node-policy/check.test.mjs', 'tests/staged-content/check.test.mjs')
        }
    }

    if ($Mode -eq 'browser') {
        # Browser installation is an explicit setup step, never part of a check.
        if (-not (Test-Path tests/deploy-smoke/node_modules/playwright/package.json)) {
            throw 'Run npm ci --prefix tests/deploy-smoke, then node tests/deploy-smoke/node_modules/playwright/cli.js install chromium.'
        }
        $expected = (Get-Content tests/deploy-smoke/package.json -Raw | ConvertFrom-Json).devDependencies.playwright
        $installed = (Get-Content tests/deploy-smoke/node_modules/playwright/package.json -Raw | ConvertFrom-Json).version
        if ($installed -ne $expected) {
            throw "Playwright $installed is installed; run npm ci --prefix tests/deploy-smoke for pinned version $expected."
        }
        Invoke-Check 'browser-smoke' 'node' @('tests/deploy-smoke/smoke.mjs')
    }
    elseif ($Mode -notin @('content', 'external-links')) {
        $msbuildArguments = if ($Serial) { @('-m:1', '-p:BuildInParallel=false', '-nodeReuse:false') } else { @() }
        Invoke-Check 'restore' 'dotnet' (@('restore', 'opengamebuilder.slnx', '--locked-mode') + $msbuildArguments)
        $formatArguments = @('format', 'opengamebuilder.slnx', '--no-restore', '--report', 'artifacts/validation/format.json')
        if (-not $Fix) { $formatArguments += '--verify-no-changes' }
        Invoke-Check 'format' 'dotnet' $formatArguments

        if ($Mode -ne 'format') {
            Invoke-Check 'build' 'dotnet' (@('build', 'opengamebuilder.slnx', '--configuration', 'Release', '--no-restore') + $msbuildArguments)
            Invoke-Check 'test' 'dotnet' @('test', '--solution', 'opengamebuilder.slnx', '--configuration', 'Release', '--no-build')
        }
        if ($Mode -eq 'full') {
            . "$PSScriptRoot/tooling.ps1"
            $bash = Resolve-CheckBash
            if (-not $SkipWebPublish) {
                # Blazor's build targets replace HTML asset placeholders. --no-build
                # can publish the source index with an unusable script URL.
                Invoke-Check 'web-publish' 'dotnet' (@(
                    'publish', 'src/OpenGameBuilder.Web.Client/OpenGameBuilder.Web.Client.csproj',
                    '--configuration', 'Release', '--no-restore', '--output', 'artifacts/web'
                ) + $msbuildArguments)
                Invoke-Check 'web-configuration' $bash @('scripts/verify-web-publish.sh', 'artifacts/web/wwwroot')
            }
            $npm = if ($IsWindows) { 'npm.cmd' } else { 'npm' }
            Invoke-Check 'smoke-dependencies' $npm @('ci', '--prefix', 'tests/deploy-smoke')
            Invoke-Check 'smoke-syntax' 'node' @('--check', 'tests/deploy-smoke/smoke.mjs')
            Invoke-Check 'browser-discovery' $npm @('run', 'test:pr', '--prefix', 'tests/deploy-smoke', '--', '--list')
            foreach ($suite in @('release-scripts', 'deploy-edge', 'deploy-topology', 'deploy-app', 'supply-chain')) {
                Invoke-Check $suite $bash @("tests/$suite/run.sh")
            }
        }
    }
    Write-Host "PASS $Mode checks"
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
finally {
    Pop-Location
}
