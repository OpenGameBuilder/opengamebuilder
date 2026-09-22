#Requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repoRoot = Split-Path -Parent $PSScriptRoot

function Find-RequiredTool {
    param([string] $Name, [string] $Remedy)
    $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { throw "$Name is missing. $Remedy" }
    return $command.Source
}

function Invoke-SetupStep {
    param([string] $Action, [string] $Command, [string[]] $Arguments)
    Write-Host $Action
    $global:LASTEXITCODE = 0
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Action failed (exit $LASTEXITCODE). Fix the diagnostic above, then rerun this script."
    }
}

Push-Location $repoRoot
try {
    $node = Find-RequiredTool 'node' 'Install Node.js 22+ (24 recommended), then restart the terminal and editor.'
    Invoke-SetupStep 'Checking Node.js policy' $node @('scripts/check-node.mjs')
    $null = Find-RequiredTool 'git' 'Install Git (Git for Windows on Windows), then restart the terminal.'
    $npm = Find-RequiredTool 'npm' 'Install npm with Node.js, then restart the terminal and editor.'

    Invoke-SetupStep 'Installing pinned npm content packages' $npm @('ci', '--ignore-scripts')
    Invoke-SetupStep 'Installing pinned native content tools' 'pwsh' @('-NoProfile', '-File', 'scripts/install-content-tools.ps1')
    Invoke-SetupStep 'Running content checks' $node @('scripts/check-content.mjs', 'all')
    Write-Host 'PASS content tooling is installed and verified.'
}
catch {
    Write-Host "[FAIL] $($_.Exception.Message)"
    exit 1
}
finally { Pop-Location }
