[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [String]
    $toolsDownloads,

    [Parameter(Mandatory)]
    [String]
    $toolsCacheFolder,

    [Parameter(Mandatory)]
    [String]
    $toolsFolder
)

. (Join-Path $PSScriptRoot functions.ps1)

# #############################################################################
# MISC ADDITIONAL SOFTWARE
# #############################################################################
Write-Host -ForegroundColor DarkYellow "INSTALLING ADDITIONAL TOOLS"
# Acquire required files and leave them in a folder for later use
Write-Host "Creating tools directory"

Write-Host "INFO: Obtaining tools in folder: $($toolsDownloads) and caching in $toolsCacheFolder."
New-Item -ItemType Directory -Force -Path $toolsCacheFolder | Out-Null

Get-RemoteFiles $toolsDownloads $toolsCacheFolder $toolsFolder