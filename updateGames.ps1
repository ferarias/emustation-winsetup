[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [String]$gamesDownloads,

    [Parameter(Mandatory = $true)]
    [String]$gameCacheFolder,

    [Parameter(Mandatory = $true)]
    [String]$RomsFolder
)

$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

. (Join-Path $PSScriptRoot functions.ps1)

# #############################################################################
# ## OPEN-SOURCE/FREEWARE ROMS INSTALLATION
# #############################################################################
Write-Host -ForegroundColor DarkYellow "INSTALLING SOME FREEWARE ROMS"
Write-Host "Creating ROM directories and filling with freeware ROMs in $RomsFolder"

if (-not (Test-Path -LiteralPath $gameCacheFolder)) {
    New-Item -ItemType Directory -Force -Path $gameCacheFolder | Out-Null
}

Write-Host "INFO: Obtaining Freeware Games lists in folder: $gamesDownloads and caching in $gameCacheFolder."

Get-ChildItem -LiteralPath $gamesDownloads -Filter "*.json" | ForEach-Object {
    Write-Host -ForegroundColor DarkGreen "Downloading and caching freeware ROMs from: $($_.FullName)"
    Get-RemoteFiles -jsonFile $_.FullName -localCacheFolder $gameCacheFolder

    $jsonContent = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
    $items = if ($jsonContent.PSObject.Properties['items']) { $jsonContent.items } else { $jsonContent }

    foreach ($item in $items) {
        if ([string]::IsNullOrWhiteSpace($item.file)) {
            continue
        }
        $sourceFile = Join-Path $gameCacheFolder $item.file
        $targetFolder = Join-Path $RomsFolder $item.platform
        $innerFolder = $item.innerFolder

        if (-not (Test-Path -LiteralPath $targetFolder)) {
            New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
        }

        if (Test-Path -LiteralPath $sourceFile) {
            $ext = [System.IO.Path]::GetExtension($sourceFile).TrimStart('.').ToLower()
            if ($CompressedFileExtensions -contains $ext) {
                Expand-PackedFile -archiveFile $sourceFile -targetFolder $targetFolder -zipFolderToCopy $innerFolder
            }
            else {
                Copy-Item -LiteralPath $sourceFile -Destination $targetFolder -Force | Out-Null
            }
        }
        else {
            Write-Host -ForegroundColor Yellow "Warning: $sourceFile not found."
        }
    }
}

# Ensure empty ROM directories exist for supported emulators
Write-Host "INFO: Creating empty ROM directories in $RomsFolder"
$standardSystems = @("atari7800", "c64", "fba", "gb", "gc", "mame", "msx", "neogeo", "wiiu", "scummvm")
foreach ($sys in $standardSystems) {
    $sysPath = Join-Path $RomsFolder $sys
    if (-not (Test-Path -LiteralPath $sysPath)) {
        New-Item -ItemType Directory -Force -Path $sysPath | Out-Null
    }
}