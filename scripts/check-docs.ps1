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
            throw "$Name failed (exit $LASTEXITCODE). See artifacts/docs/$Name.log."
        }
    }

    Invoke-DocsCheck 'prerequisites' 'pwsh' @('-NoProfile', '-File', 'scripts/doctor.ps1', '-Scope', 'quick')
    if ((& node --version) -notmatch '^v22\.') { throw 'Documentation checks require Node.js 22 on PATH.' }
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
    Write-Error $_ -ErrorAction Continue
    exit 1
}
finally { Pop-Location }
