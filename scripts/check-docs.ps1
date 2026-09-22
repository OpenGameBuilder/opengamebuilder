#Requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
    New-Item -ItemType Directory -Force artifacts/docs | Out-Null
    function Invoke-DocsCheck {
        param([string] $Name, [string] $Command, [string[]] $Arguments)
        & $Command @Arguments 2>&1 | Tee-Object -FilePath "$repoRoot/artifacts/docs/$Name.log"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Check stopped. Details: artifacts/docs/$Name.log."
            exit $LASTEXITCODE
        }
    }

    Invoke-DocsCheck 'prerequisites' 'pwsh' @('-NoProfile', '-File', 'scripts/doctor.ps1', '-Scope', 'quick')
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        throw 'Node.js is missing. Install the recommended version from .node-version, then restart your terminal or editor.'
    }
    Invoke-DocsCheck 'node-policy' 'node' @('scripts/check-node.mjs')
    & "$PSScriptRoot/install-content-tools.ps1" -Verify

    # Clear only this fixed generated directory so removed pages cannot survive.
    $sitePath = [IO.Path]::GetFullPath((Join-Path $repoRoot 'artifacts/docs/site'))
    $artifactRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot 'artifacts')) + [IO.Path]::DirectorySeparatorChar
    if (-not $sitePath.StartsWith($artifactRoot, [StringComparison]::Ordinal)) {
        throw 'Documentation output must stay inside repository artifacts.'
    }
    if (Test-Path -LiteralPath $sitePath) { Remove-Item -LiteralPath $sitePath -Recurse -Force }

    Invoke-DocsCheck 'source-metadata' 'node' @('scripts/docs-links.mjs', 'prepare')

    Push-Location docs
    try {
        Invoke-DocsCheck 'tool-restore' 'dotnet' @('tool', 'restore', '--configfile', '../NuGet.Config')
        Invoke-DocsCheck 'build' 'dotnet' @(
            'tool', 'run', 'docfx', '--', 'build', '../docfx.json',
            '--warningsAsErrors', '--log', '../artifacts/docs/diagnostics.log'
        )
    }
    finally { Pop-Location }
    Invoke-DocsCheck 'source-links' 'node' @('scripts/docs-links.mjs', 'resolve')
    Invoke-DocsCheck 'rendered-site' 'node' @('scripts/check-docs.mjs')
    Invoke-DocsCheck 'regressions' 'node' @('--test', 'tests/docs-site/check.test.mjs')
    Write-Host 'PASS documentation build, rendered links, search inventory, and regression checks'
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
finally { Pop-Location }
