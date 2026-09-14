[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [String]$InstallDir,

    [switch]$Force
)

$ErrorActionPreference = "Stop"

function RemoveIfExists {
    param ([String]$file)

    if (Test-Path -LiteralPath $file) {
        Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
    }
}

# Resolve to full absolute path
$InstallDir = [System.IO.Path]::GetFullPath($InstallDir)

# Safety check: Prevent destructive uninstall of system roots or user home
$forbiddenRoots = @(
    [System.IO.Path]::GetPathRoot($InstallDir),
    $env:SystemRoot,
    $env:ProgramFiles,
    ${env:ProgramFiles(x86)},
    $env:USERPROFILE,
    $env:TEMP
)
if ($forbiddenRoots -contains $InstallDir) {
    throw "ERROR: Cannot uninstall from protected directory: $InstallDir"
}

# Validate that the target contains EmulationStation indicators before wiping
$esIndicator = Join-Path $InstallDir "EmulationStation"
if ((Test-Path -LiteralPath $InstallDir) -and !(Test-Path -LiteralPath $esIndicator)) {
    if (!$Force) {
        throw "ERROR: Directory '$InstallDir' does not appear to contain an EmulationStation installation. Use -Force if you are sure."
    }
}

Write-Host "INFO: Script directory is: $PSScriptRoot"
Write-Host "INFO: Install directory is: $InstallDir"

Write-Host "INFO: Removing desktop shortcuts"
$desktop = [System.Environment]::GetFolderPath('Desktop')
RemoveIfExists "$desktop\EmulationStation (Windowed).lnk"
RemoveIfExists "$desktop\EmulationStation.lnk"
RemoveIfExists "$desktop\Cores.lnk"
RemoveIfExists "$desktop\Roms.lnk"
RemoveIfExists "$InstallDir\EmulationStation (Windowed).lnk"
RemoveIfExists "$InstallDir\EmulationStation.lnk"
RemoveIfExists "$InstallDir\Cores.lnk"
RemoveIfExists "$InstallDir\Roms.lnk"

$esUserFolder = "$env:userprofile\.emulationstation"
Write-Host "INFO: Removing Emulation Station user folder: $esUserFolder"
if (Test-Path -LiteralPath $esUserFolder) {
    Remove-Item -Recurse -Force -LiteralPath $esUserFolder -ErrorAction SilentlyContinue
}

$requirementsFolder = "$PSScriptRoot\requirements"
$recalboxThemeFolder = "$requirementsFolder\recalbox-backport"
if (Test-Path -LiteralPath $recalboxThemeFolder) {
    Write-Host "INFO: Removing RecalBox theme folder: $recalboxThemeFolder"
    Remove-Item -Recurse -Force -LiteralPath $recalboxThemeFolder -ErrorAction SilentlyContinue
}

if (Test-Path -LiteralPath $InstallDir) {
    Write-Host "INFO: Removing install folder: $InstallDir"
    Remove-Item -Recurse -Force -LiteralPath $InstallDir
}

Write-Host "INFO: Uninstall completed"