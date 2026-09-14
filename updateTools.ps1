[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [String]$toolsDownloads,

    [Parameter(Mandatory = $true)]
    [String]$toolsCacheFolder,

    [Parameter(Mandatory = $true)]
    [String]$toolsFolder
)

$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

. (Join-Path $PSScriptRoot functions.ps1)

# #############################################################################
# MISC ADDITIONAL SOFTWARE
# #############################################################################
Write-Host -ForegroundColor DarkYellow "INSTALLING ADDITIONAL TOOLS"
Write-Host "Creating tools directory in $toolsFolder"

if (-not (Test-Path -LiteralPath $toolsCacheFolder)) {
    New-Item -ItemType Directory -Force -Path $toolsCacheFolder | Out-Null
}

if (-not (Test-Path -LiteralPath $toolsFolder)) {
    New-Item -ItemType Directory -Force -Path $toolsFolder | Out-Null
}

Write-Host "INFO: Obtaining tools in folder: $toolsDownloads and caching in $toolsCacheFolder."
Get-RemoteFiles -jsonFile $toolsDownloads -localCacheFolder $toolsCacheFolder -targetFolder $toolsFolder