param (
    [Parameter(Mandatory)]
    $InstallDir
)

function RemoveIfExists {
    param ([String]$file)

    if(Test-Path $file) {
        Remove-Item -Path $file
    }
}


$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path $scriptPath
Write-Host "INFO: Script directory is: $scriptDir"

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
if(Test-Path $esUserFolder) {
    Remove-Item -Recurse -Force -Path $esUserFolder
}

$requirementsFolder = "$PSScriptRoot\requirements"

$recalboxThemeFolder = "$requirementsFolder\recalbox-backport"
if(Test-Path $recalboxThemeFolder) {
    Write-Host "INFO: Removing RecalBox theme folder: $recalboxThemeFolder"
    Remove-Item -Recurse -Force -Path $recalboxThemeFolder
}

# Write-Host "INFO: Removing Requirements folder: $requirementsFolder"
# if(Test-Path $requirementsFolder) {
#     Remove-Item -Recurse -Force -Path $requirementsFolder
# }

if(Test-Path $InstallDir) {
    Write-Host "INFO: Removing install folder: $InstallDir"
    Remove-Item -Recurse -Force -Path $InstallDir
}

Write-Host "INFO: Uninstall completed"