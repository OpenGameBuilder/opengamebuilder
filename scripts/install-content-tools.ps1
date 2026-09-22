#Requires -Version 7.0
<#
.SYNOPSIS
Installs or verifies the repository's pinned native content-checking tools.
#>
[CmdletBinding()]
param(
    [switch] $Verify
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

function Get-ContentToolsPlatform {
    $architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    if ($architecture -ne [System.Runtime.InteropServices.Architecture]::X64) {
        throw "Content tools support only x64 hosts; detected $architecture."
    }

    if ($IsWindows) { return 'windows-x64' }
    if ($IsLinux) { return 'linux-x64' }
    throw 'Content tools support only Windows x64 and Linux x64.'
}

function Resolve-ChildPath {
    param(
        [Parameter(Mandatory)] [string] $Parent,
        [Parameter(Mandatory)] [string] $Child
    )

    $parentPath = [System.IO.Path]::GetFullPath($Parent)
    $childPath = [System.IO.Path]::GetFullPath($Child)
    $separator = [System.IO.Path]::DirectorySeparatorChar
    $parentPrefix = $parentPath.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + $separator
    $comparison = if ($IsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparison]::Ordinal
    }

    if (-not $childPath.StartsWith($parentPrefix, $comparison)) {
        throw "Path '$childPath' is outside '$parentPath'."
    }
    return $childPath
}

function Get-Sha256 {
    param([Parameter(Mandatory)] [string] $Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-Sha256Value {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Value
    )

    if ($Value -cnotmatch '^[0-9a-f]{64}$') {
        throw "Manifest value '$Name' must be a lowercase SHA-256 hash."
    }
}

function Test-InstalledTool {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $ExpectedSha256
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    if ((Get-Sha256 -Path $Path) -cne $ExpectedSha256) { return $false }
    if (-not $IsWindows) {
        $executeBits = [System.IO.UnixFileMode]::UserExecute -bor
            [System.IO.UnixFileMode]::GroupExecute -bor
            [System.IO.UnixFileMode]::OtherExecute
        $mode = [System.IO.File]::GetUnixFileMode($Path)
        if (($mode -band $executeBits) -ne $executeBits) { return $false }
    }
    return $true
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$manifestPath = Resolve-ChildPath -Parent $repositoryRoot -Child (Join-Path $PSScriptRoot 'content-tools.json')
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1) {
    throw "Unsupported content-tools manifest schema '$($manifest.schemaVersion)'."
}

$platform = Get-ContentToolsPlatform
$contentToolsRoot = Resolve-ChildPath -Parent $repositoryRoot -Child (
    Join-Path $repositoryRoot "artifacts/content-tools/$platform"
)
$installCommand = 'pwsh ./scripts/install-content-tools.ps1'

$tools = @($manifest.tools.PSObject.Properties)
if ($tools.Count -eq 0) { throw 'The content-tools manifest contains no tools.' }

if ($Verify) {
    $problems = [System.Collections.Generic.List[string]]::new()
    foreach ($toolProperty in $tools) {
        $name = $toolProperty.Name
        $tool = $toolProperty.Value
        $asset = $tool.platforms.$platform
        if (-not $asset) {
            $problems.Add("$name has no $platform asset")
            continue
        }

        Assert-Sha256Value -Name "$name executableSha256" -Value $asset.executableSha256
        $toolDirectory = Resolve-ChildPath -Parent $contentToolsRoot -Child (Join-Path $contentToolsRoot $name)
        $executablePath = Resolve-ChildPath -Parent $toolDirectory -Child (
            Join-Path $toolDirectory $asset.executable
        )
        if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
            $problems.Add("$name $($tool.version) is missing at $executablePath")
            continue
        }
        if (-not (Test-InstalledTool -Path $executablePath -ExpectedSha256 $asset.executableSha256)) {
            $problems.Add("$name $($tool.version) is stale or corrupt at $executablePath")
            continue
        }

        Write-Host "$name $($tool.version) $executablePath"
    }

    if ($problems.Count -gt 0) {
        throw (($problems -join [Environment]::NewLine) +
            "`nInstall the pinned tools with: $installCommand")
    }
    return
}

New-Item -ItemType Directory -Path $contentToolsRoot -Force | Out-Null
foreach ($toolProperty in $tools) {
    $name = $toolProperty.Name
    $tool = $toolProperty.Value
    $asset = $tool.platforms.$platform
    if (-not $asset) { throw "$name has no $platform asset." }
    if ($asset.archiveType -notin @('file', 'zip', 'tar.gz')) {
        throw "$name has unsupported archive type '$($asset.archiveType)'."
    }
    $assetUri = $null
    if (-not [System.Uri]::TryCreate(
            [string] $asset.url,
            [System.UriKind]::Absolute,
            [ref] $assetUri
        ) -or $assetUri.Scheme -ne [System.Uri]::UriSchemeHttps) {
        throw "$name asset URL must use HTTPS."
    }
    if ([System.IO.Path]::GetFileName([string] $asset.executable) -cne $asset.executable) {
        throw "$name executable must be a file name without directory components."
    }
    Assert-Sha256Value -Name "$name archiveSha256" -Value $asset.archiveSha256
    Assert-Sha256Value -Name "$name executableSha256" -Value $asset.executableSha256

    $toolDirectory = Resolve-ChildPath -Parent $contentToolsRoot -Child (Join-Path $contentToolsRoot $name)
    $executablePath = Resolve-ChildPath -Parent $toolDirectory -Child (
        Join-Path $toolDirectory $asset.executable
    )
    if (Test-InstalledTool -Path $executablePath -ExpectedSha256 $asset.executableSha256) {
        Write-Host "$name $($tool.version) $executablePath"
        continue
    }

    $temporaryRoot = Resolve-ChildPath -Parent $contentToolsRoot -Child (
        Join-Path $contentToolsRoot ('.install-' + $name + '-' + [guid]::NewGuid().ToString('N'))
    )
    New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
    try {
        $sourceRoot = Resolve-ChildPath -Parent $temporaryRoot -Child (Join-Path $temporaryRoot 'source')
        New-Item -ItemType Directory -Path $sourceRoot | Out-Null
        $downloadName = if ($asset.archiveType -eq 'file') { $asset.executable } else { 'asset' }
        $downloadPath = Resolve-ChildPath -Parent $sourceRoot -Child (Join-Path $sourceRoot $downloadName)

        Write-Host "Downloading $name $($tool.version) from $($asset.url)"
        Invoke-WebRequest -Uri $asset.url -OutFile $downloadPath
        $downloadSha256 = Get-Sha256 -Path $downloadPath
        if ($downloadSha256 -cne $asset.archiveSha256) {
            throw "$name asset checksum mismatch: expected $($asset.archiveSha256), got $downloadSha256."
        }

        if ($asset.archiveType -ne 'file') {
            $extractRoot = Resolve-ChildPath -Parent $temporaryRoot -Child (Join-Path $temporaryRoot 'extracted')
            New-Item -ItemType Directory -Path $extractRoot | Out-Null
            if ($asset.archiveType -eq 'zip') {
                Expand-Archive -LiteralPath $downloadPath -DestinationPath $extractRoot
            }
            else {
                & tar '--extract' '--gzip' '--file' $downloadPath '--directory' $extractRoot
                if ($LASTEXITCODE -ne 0) {
                    throw "$name archive extraction failed with exit code $LASTEXITCODE."
                }
            }
            $sourceRoot = $extractRoot
        }

        $candidates = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File |
            Where-Object { $_.Name -ceq $asset.executable })
        if ($candidates.Count -ne 1) {
            throw "$name asset must contain exactly one '$($asset.executable)'; found $($candidates.Count)."
        }

        $candidatePath = Resolve-ChildPath -Parent $sourceRoot -Child $candidates[0].FullName
        $candidateSha256 = Get-Sha256 -Path $candidatePath
        if ($candidateSha256 -cne $asset.executableSha256) {
            throw "$name executable checksum mismatch: expected $($asset.executableSha256), got $candidateSha256."
        }

        New-Item -ItemType Directory -Path $toolDirectory -Force | Out-Null
        Copy-Item -LiteralPath $candidatePath -Destination $executablePath -Force
        if (-not $IsWindows) {
            & chmod '755' '--' $executablePath
            if ($LASTEXITCODE -ne 0) {
                throw "$name chmod failed with exit code $LASTEXITCODE."
            }
        }
        if (-not (Test-InstalledTool -Path $executablePath -ExpectedSha256 $asset.executableSha256)) {
            throw "$name failed verification after installation."
        }
    }
    finally {
        if (Test-Path -LiteralPath $temporaryRoot) {
            $temporaryRoot = Resolve-ChildPath -Parent $contentToolsRoot -Child $temporaryRoot
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }

    Write-Host "$name $($tool.version) $executablePath"
}
