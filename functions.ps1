using namespace System.IO

$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

$CompressedFileExtensions = "zip", "7z", "gz", "gzip"

# Cache for GitHub Release responses across function calls within the session
if (-not (Get-Variable -Name "GitHubReleaseCache" -Scope Script -ErrorAction SilentlyContinue)) {
    $script:GitHubReleaseCache = @{}
}

Function Get-MyModule {
    Param(
        [string]$name
    )

    if (-not(Get-Module -name $name)) {
        if (Get-Module -ListAvailable | Where-Object { $_.name -eq $name }) {
            Import-Module -Name $name
            $true
        } 
        else { $false }
    } 
    else { $true }
} 

Function Resolve-GitHubReleaseAsset {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$FilePattern,
        [Parameter(Mandatory = $false)][string]$Tag
    )

    $cacheKey = if ([string]::IsNullOrWhiteSpace($Tag)) { "$($Repo)/latest" } else { "$($Repo)/tags/$Tag" }
    
    if ($script:GitHubReleaseCache.ContainsKey($cacheKey)) {
        Write-Verbose "Using cached release metadata for $cacheKey"
        $release = $script:GitHubReleaseCache[$cacheKey]
    }
    else {
        $headers = @{
            "User-Agent" = "PowerShell/emustation-winsetup"
            "Accept"     = "application/vnd.github.v3+json"
        }
        if (![string]::IsNullOrEmpty($env:GITHUB_TOKEN)) {
            $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
        }
        elseif (![string]::IsNullOrEmpty($env:GH_TOKEN)) {
            $headers["Authorization"] = "Bearer $env:GH_TOKEN"
        }

        $endpoint = if ([string]::IsNullOrWhiteSpace($Tag)) {
            "https://api.github.com/repos/$Repo/releases/latest"
        }
        else {
            "https://api.github.com/repos/$Repo/releases/tags/$Tag"
        }

        Write-Host "Querying GitHub release for $Repo ($endpoint)..."
        try {
            $release = Invoke-RestMethod -Uri $endpoint -Headers $headers -TimeoutSec 30
            $script:GitHubReleaseCache[$cacheKey] = $release
        }
        catch {
            $statusCode = $null
            if ($_.Exception -and $_.Exception.Response) {
                $statusCode = $_.Exception.Response.StatusCode.value__
            }
            # Handle rate limit (403) with direct URL fallback if pattern contains no wildcards
            if ($statusCode -eq 403 -and -not ($FilePattern.Contains('*') -or $FilePattern.Contains('?'))) {
                Write-Warning "GitHub API rate limit exceeded or access forbidden. Falling back to direct download link."
                $directUrl = if ([string]::IsNullOrWhiteSpace($Tag)) {
                    "https://github.com/$Repo/releases/latest/download/$FilePattern"
                }
                else {
                    "https://github.com/$Repo/releases/download/$Tag/$FilePattern"
                }
                return [PSCustomObject]@{
                    Name = $FilePattern
                    Url  = $directUrl
                    Size = $null
                }
            }
            # If /releases/latest returned 404, fallback to first release in /releases (e.g. if only prereleases exist)
            elseif ($statusCode -eq 404 -and [string]::IsNullOrWhiteSpace($Tag)) {
                Write-Verbose "/releases/latest returned 404, checking /releases list..."
                $fallbackEndpoint = "https://api.github.com/repos/$Repo/releases?per_page=5"
                try {
                    $releasesList = Invoke-RestMethod -Uri $fallbackEndpoint -Headers $headers -TimeoutSec 30
                    if ($releasesList -and $releasesList.Count -gt 0) {
                        $release = $releasesList[0]
                        $script:GitHubReleaseCache[$cacheKey] = $release
                    }
                    else {
                        throw "No releases found for repository $Repo."
                    }
                }
                catch {
                    throw "Failed to fetch releases for $Repo`: $($_.Exception.Message)"
                }
            }
            else {
                throw "GitHub API request failed for $Repo ($endpoint)`: $($_.Exception.Message)"
            }
        }
    }

    if ($null -eq $release -or $null -eq $release.assets) {
        throw "No assets found in release for $Repo."
    }

    $matchedAsset = $release.assets | Where-Object { $_.name -like $FilePattern } | Select-Object -First 1
    if ($null -eq $matchedAsset) {
        $available = ($release.assets | ForEach-Object { $_.name }) -join ", "
        throw "No asset matching pattern '$FilePattern' found in $Repo release '$($release.tag_name)'. Available assets: $available"
    }

    return [PSCustomObject]@{
        Name = $matchedAsset.name
        Url  = $matchedAsset.browser_download_url
        Size = $matchedAsset.size
    }
}

Function Invoke-ResilientDownload {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [int]$MaxRetries = 3,
        [int]$InitialDelaySec = 2
    )

    $parentDir = Split-Path -Parent $OutputFile
    if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
    }

    $tempFile = "$OutputFile.tmp"
    if (Test-Path -LiteralPath $tempFile) {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }

    $attempt = 0
    $success = $false
    $lastError = $null

    while ($attempt -lt $MaxRetries -and -not $success) {
        $attempt++
        try {
            Write-Host -ForegroundColor Green " Downloading $Url to $OutputFile (attempt $attempt/$MaxRetries)..."
            Invoke-WebRequest -Uri $Url -OutFile $tempFile -UseBasicParsing -TimeoutSec 120
            
            # Verify file exists and is not 0 bytes
            if ((Test-Path -LiteralPath $tempFile) -and (Get-Item -LiteralPath $tempFile).Length -gt 0) {
                if (Test-Path -LiteralPath $OutputFile) {
                    Remove-Item -LiteralPath $OutputFile -Force
                }
                Move-Item -LiteralPath $tempFile -Destination $OutputFile -Force
                $success = $true
            }
            else {
                throw "Downloaded file is empty or missing."
            }
        }
        catch {
            $lastError = $_
            Write-Warning "Download attempt $attempt failed: $($_.Exception.Message)"
            if (Test-Path -LiteralPath $tempFile) {
                Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
            }
            if ($attempt -lt $MaxRetries) {
                $delay = $InitialDelaySec * [Math]::Pow(2, $attempt - 1)
                Write-Host "Waiting $delay seconds before retry..."
                Start-Sleep -Seconds $delay
            }
        }
    }

    if (-not $success) {
        throw "Failed to download $Url after $MaxRetries attempts. Last error: $($lastError.Exception.Message)"
    }
}

Function Get-RemoteFiles {
    param (
        [parameter(Mandatory = $true)][string]$jsonFile,
        [parameter(Mandatory = $true)][string]$localCacheFolder,
        [parameter(Mandatory = $false)][string]$targetFolder
    )
    
    if (-not (Test-Path -LiteralPath $jsonFile)) {
        throw "JSON configuration file '$jsonFile' not found."
    }

    if (-not (Test-Path -LiteralPath $localCacheFolder)) {
        New-Item -ItemType Directory -Force -Path $localCacheFolder | Out-Null
    }

    $jsonContent = Get-Content -LiteralPath $jsonFile -Raw | ConvertFrom-Json
    $items = if ($jsonContent.PSObject.Properties['items']) { $jsonContent.items } else { $jsonContent }

    foreach ($item in $items) {
        $file = $item.file
        $url = $item.url
        $repo = $item.repo
        $tag = $item.tag

        if ($null -ne $repo -and $repo -ne "") {
            $resolved = Resolve-GitHubReleaseAsset -Repo $repo -FilePattern $file -Tag $tag
            $url = $resolved.Url
            $output = Join-Path $localCacheFolder $resolved.Name
        }
        else {
            if ([string]::IsNullOrWhiteSpace($url)) {
                Write-Warning "Skipping item without URL or Repo in $jsonFile"
                continue
            }
            $uri = New-Object Uri($url)
            $name = [System.IO.Path]::GetFileName($uri.LocalPath)
            if ([string]::IsNullOrWhiteSpace($name)) {
                $name = $file
            }
            $output = Join-Path $localCacheFolder $name
        }
        
        if (![System.IO.File]::Exists($output) -or (Get-Item -LiteralPath $output).Length -eq 0) {
            Invoke-ResilientDownload -Url $url -OutputFile $output
        }
        else {
            Write-Host -ForegroundColor Gray " Already downloaded $output... skipped."
        }

        if (-not [string]::IsNullOrEmpty($targetFolder)) {
            $targetSubfolder = if ($item.folder) { Join-Path $targetFolder $item.folder } else { $targetFolder }
            $innerFolder = $item.innerFolder
            Write-Host -ForegroundColor Cyan "Installing $output in $targetSubfolder"
            $fileExtension = [System.IO.Path]::GetExtension($output).TrimStart('.').ToLower()
            if ($CompressedFileExtensions -contains $fileExtension) {
                Expand-PackedFile -archiveFile $output -targetFolder $targetSubfolder -zipFolderToCopy $innerFolder | Out-Null
            }
            else {
                if (-not (Test-Path -LiteralPath $targetSubfolder)) {
                    New-Item -ItemType Directory -Force -Path $targetSubfolder | Out-Null
                }
                Copy-Item -LiteralPath $output -Destination $targetSubfolder -Force
            }
        }
    }
}

Function Find-7ZipExe {
    if ($GLOBAL:GLOBAL_7ZIP_EXE -and (Test-Path -LiteralPath $GLOBAL:GLOBAL_7ZIP_EXE)) {
        return $GLOBAL:GLOBAL_7ZIP_EXE
    }

    $candidates = @(
        (Get-Command 7z.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
        "$env:ProgramFiles\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
        "$PSScriptRoot\.cache\7z\7z.exe"
    )

    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) {
            $GLOBAL:GLOBAL_7ZIP_EXE = $c
            return $c
        }
    }

    return $null
}

Function Expand-PackedFile {
    param (
        [String]$archiveFile,
        [String]$targetFolder,
        [string]$zipFolderToCopy
    )

    if (-not (Test-Path -LiteralPath $archiveFile)) {
        throw "ERROR: Archive file '$archiveFile' not found."
    }

    $tempFolder = New-TemporaryDirectory
    try {
        # Create target directory
        if (-not (Test-Path -LiteralPath $targetFolder)) {
            New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
        }
        # Extract to temp folder
        Extract -Path $archiveFile -Destination $tempFolder | Out-Null

        # Determine source to move
        $sourceDir = if ([string]::IsNullOrEmpty($zipFolderToCopy)) {
            $tempFolder
        }
        else {
            Join-Path $tempFolder $zipFolderToCopy
        }

        if (-not (Test-Path -LiteralPath $sourceDir)) {
            throw "Expected extraction inner folder '$sourceDir' does not exist."
        }

        # Move files to final directory using Robocopy
        & Robocopy.exe $sourceDir $targetFolder /E /NFL /NDL /NJH /NJS /nc /ns /np /MOVE | Out-Null
        if ($LASTEXITCODE -ge 8) {
            throw "Robocopy failed moving files from '$sourceDir' to '$targetFolder' with exit code $LASTEXITCODE."
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempFolder) {
            Remove-Item -LiteralPath $tempFolder -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

Function Extract([string]$Path, [string]$Destination) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Extract: source file '$Path' not found."
    }

    $exe7z = Find-7ZipExe
    if ($exe7z) {
        $sevenZipArguments = @('x', '-y', "-o$Destination", $Path)
        & $exe7z $sevenZipArguments | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "7-Zip failed to extract '$Path' with exit code $LASTEXITCODE."
        }
    }
    else {
        # Fallback to built-in Expand-Archive if .zip
        $ext = [System.IO.Path]::GetExtension($Path).ToLower()
        if ($ext -eq ".zip") {
            Write-Host "7-Zip not found, using built-in Expand-Archive for $Path..."
            Expand-Archive -LiteralPath $Path -DestinationPath $Destination -Force
        }
        else {
            throw "7-Zip executable not found and archive '$Path' is not a standard .zip archive."
        }
    }
}

Function Write-ESSystemsConfig {
    param(
        [String] $ConfigFile,
        [hashtable] $Systems,
        [string] $RomsPath
    )

    $configDir = Split-Path -Parent $ConfigFile
    if ($configDir -and -not (Test-Path -LiteralPath $configDir)) {
        New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    }

    $xmlWriter = New-Object System.Xml.XmlTextWriter($ConfigFile, [System.Text.Encoding]::UTF8)
    try {
        $xmlWriter.Formatting = 'Indented'
        $xmlWriter.Indentation = 1
        $xmlWriter.IndentChar = "`t"
        $xmlWriter.WriteStartDocument()
        $xmlWriter.WriteStartElement('systemList')
        
        foreach ($item in $Systems.GetEnumerator()) {
            $xmlWriter.WriteStartElement('system')
            $xmlWriter.WriteElementString('name', [string]$item.Key)
            $xmlWriter.WriteElementString('fullname', [string]$item.Value[0])
            $xmlWriter.WriteElementString('path', "$RomsPath/" + $item.Key)
            $xmlWriter.WriteElementString('extension', [string]$item.Value[1])
            $xmlWriter.WriteElementString('command', [string]$item.Value[2])
            $xmlWriter.WriteElementString('platform', [string]$item.Value[3])
            $xmlWriter.WriteElementString('theme', [string]$item.Value[4])
            $xmlWriter.WriteEndElement()
        }
        $xmlWriter.WriteEndElement()
        $xmlWriter.WriteEndDocument()
        $xmlWriter.Flush()
    }
    finally {
        $xmlWriter.Close()
    }
}

Function Add-Shortcut {
    param (
        [String]$ShortcutLocation,
        [String]$ShortcutTarget,
        [String]$ShortcutIcon,
        [String]$WorkingDir
    )

    $parentDir = Split-Path -Parent $ShortcutLocation
    if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
    }

    $wshshell = New-Object -ComObject WScript.Shell
    $link = $wshshell.CreateShortcut($ShortcutLocation)
    $link.TargetPath = $ShortcutTarget
    if (-Not [String]::IsNullOrEmpty($WorkingDir)) {
        $link.WorkingDirectory = $WorkingDir
    }
    if (-Not [String]::IsNullOrEmpty($ShortcutIcon) -and (Test-Path -LiteralPath $ShortcutIcon)) {
        $link.IconLocation = $ShortcutIcon
    }
    $link.Save() 
}

Function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}