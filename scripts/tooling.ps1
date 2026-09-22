function Resolve-CheckBash {
    [CmdletBinding()]
    param([switch] $AllowMissing)

    if ($IsWindows) {
        if ($env:ProgramFiles) {
            $preferred = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
            if (Test-Path -LiteralPath $preferred -PathType Leaf) {
                return $preferred
            }
        }

        $git = Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($git -and $git.Path) {
            $gitRoot = Split-Path -Parent (Split-Path -Parent $git.Path)
            $alongsideGit = Join-Path $gitRoot 'bin\bash.exe'
            if (Test-Path -LiteralPath $alongsideGit -PathType Leaf) {
                return $alongsideGit
            }
        }

        $pathBash = Get-Command bash -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pathBash -and $pathBash.Path) {
            $wslLauncher = Join-Path $env:SystemRoot 'System32\bash.exe'
            if ($pathBash.Path -ne $wslLauncher) {
                return $pathBash.Path
            }
        }
    }
    else {
        $bash = Get-Command bash -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($bash -and $bash.Path) {
            return $bash.Path
        }
    }

    if ($AllowMissing) {
        return $null
    }

    $remedy = if ($IsWindows) {
        'Install Git for Windows; the WSL bash launcher is not used for repository checks.'
    }
    else {
        'Install Bash and add it to PATH.'
    }
    throw "Bash is required. $remedy"
}
