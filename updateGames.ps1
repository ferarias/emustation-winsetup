[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [String]
    $gamesDownloads,

    [Parameter(Mandatory)]
    [String]
    $gameCacheFolder,

    [Parameter(Mandatory)]
    [String]
    $RomsFolder
)

. (Join-Path $PSScriptRoot functions.ps1)

# #############################################################################
# ## OPEN-SOURCE/FREEWARE ROMS INSTALLATION
# #############################################################################
Write-Host -ForegroundColor DarkYellow "INSTALLING SOME FREEWARE ROMS"
# Acquire required files and leave them in a folder for later use
# Look into the downloads/games folder to see what downloads are configured
Write-Host "Creating ROM directories and filling with freeware ROMs in $RomsFolder"

Write-Host "INFO: Obtaining Freeware Games lists in folder: $($gamesDownloads) and caching in $gameCacheFolder."
New-Item -ItemType Directory -Force -Path $gameCacheFolder | Out-Null

Get-ChildItem $gamesDownloads -Filter "*.json" | ForEach-Object {
    Write-Host -ForegroundColor DarkGreen "Downloading and caching freeware ROMs from: $_"
    Get-RemoteFiles $_.FullName $gameCacheFolder

    Get-Content $_.FullName | ConvertFrom-Json | Select-Object -ExpandProperty items | ForEach-Object {
        if ([String]::IsNullOrEmpty( $_.file ) ) {
            continue;
        }
        $sourceFile = [Path]::Combine($gameCacheFolder, $_.file)
        $targetFolder = [Path]::Combine($RomsFolder, $_.platform)
        $innerFolder = $_.innerFolder
        if ((Test-Path $targetFolder) -ne $true) {
            New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
        }
        if (Test-Path -LiteralPath $sourceFile) {
            if ( $sourceFile.EndsWith("zip") -or $sourceFile.EndsWith("7z") -or $sourceFile.EndsWith("gz") ) {
                Expand-PackedFile $sourceFile $targetFolder $innerFolder
            }
            else {
                Copy-Item -Path $sourceFile -Destination $targetFolder -Force | Out-Null
            }
        }
        else {
            Write-Host -ForegroundColor Red "Warning: $sourceFile not found."
        }
    }
}

# TODO: find and test freeware games for these emulators.
Write-Host "INFO: Creating empty ROM directories $path"
New-Item -ItemType Directory -Force -Path "$RomsFolder\atari7800" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\c64" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\fba" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\gb" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\gc" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\mame" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\msx" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\neogeo" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\wiiu" | Out-Null
New-Item -ItemType Directory -Force -Path "$RomsFolder\scummvm" | Out-Null