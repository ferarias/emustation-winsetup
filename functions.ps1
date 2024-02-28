using namespace System.IO

$CompressedFileExtensions = "zip", "7z", "gz", "gzip"

Function Get-MyModule {
    Param(
        [string]$name
    )

    if (-not(Get-Module -name $name)) {
        if (Get-Module -ListAvailable |
            Where-Object { $_.name -eq $name }) {
            Import-Module -Name $name
            $true
        } 
        else { $false }
    } 
    else { $true }
} 


Function Get-RemoteFiles {
    param (
        [parameter(Mandatory = $true)][string]$jsonFile,
        [parameter(Mandatory = $true)][string]$localCacheFolder,
        [parameter(Mandatory = $false)][string]$targetFolder
    )
    
    Get-Content $jsonFile | ConvertFrom-Json | Select-Object -ExpandProperty items | ForEach-Object {
    
        $file = $_.file
        $url = $_.url
        $repo = $_.repo
        $tag = $_.tag
        if($Null -ne $repo) {
            # This is a GitHub repo.
            $releasesUri = "https://api.github.com/repos/$repo/releases"
            $releasesResponse = Invoke-WebRequest $releasesUri -UseBasicParsing | ConvertFrom-Json
            if($Null -ne $releasesResponse) {
                if($Null -ne $tag) {
                    $taggedRelease = $releasesResponse |  Where-Object -Property tag_name -eq $tag
                    $asset = $taggedRelease.assets | Where-Object -Property name -Like $file
                } else {
                    $asset = $releasesResponse[0].assets | Where-Object -Property name -Like $file
                }
            } 
            $url = $asset.browser_download_url;
            $output = "$localCacheFolder\$($asset.name)"
        } else {
            $uri = New-Object Uri($url)
            $name = [System.IO.Path]::GetFileName($uri)
            $output = "$localCacheFolder\$($name)"
        }
        
        if (![System.IO.File]::Exists($output)) {
    
            Write-Host -ForegroundColor Green " Downloading $url to $output..."
            Invoke-WebRequest $url -Out $output   
        }
        else {
            Write-Host -ForegroundColor Gray " Already downloaded $output... skipped."
        }

        if($targetFolder -ne "") {
            $installPath = [Path]::Combine($targetFolder, $_.folder)
            $innerFolder = $_.innerFolder
            Write-Host -ForegroundColor Cyan "Installing $output in $installPath"
            $fileExtension = [System.IO.Path]::GetExtension($output).TrimStart('.')
            if ($CompressedFileExtensions -contains $fileExtension) {
                Expand-PackedFile $output $installPath $innerFolder | Out-Null
            } else {
                Copy-Item -Path $output -Destination $installPath
            }
        }
    }
}

Function Expand-PackedFile {
    param (
        [String]$archiveFile,
        [String]$targetFolder,
        [string]$zipFolderToCopy
    )
    $tempFolder = New-TemporaryDirectory
    try {
        if (Test-Path -LiteralPath $archiveFile) {
            # Create target directory
            New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
            # Extract to a temp folder
            Extract -Path $archiveFile -Destination $tempFolder | Out-Null
            # Move files to the final directory in systems folder
            if ($zipFolderToCopy -eq "") {
                Robocopy.exe $tempFolder $targetFolder /E /NFL /NDL /NJH /NJS /nc /ns /np /MOVE | Out-Null
            }
            else {
                Robocopy.exe $tempFolder/$zipFolderToCopy $targetFolder /E /NFL /NDL /NJH /NJS /nc /ns /np /MOVE | Out-Null
            }
        }
        else {
            Write-Host -ForegroundColor Red "ERROR: $archiveFile not found."
            exit -1
        }
    }
    finally {
        if (Test-Path $tempFolder) {
            Remove-Item $tempFolder -Force -Recurse | Out-Null
        }
    }
    
}

Function Extract([string]$Path, [string]$Destination) {
    $sevenZipArguments = New-Object String[] 4
    $sevenZipArguments[0] = 'x'
    $sevenZipArguments[1] = '-y'
    $sevenZipArguments[2] = '-o' + $Destination
    $sevenZipArguments[3] = $Path
    & $GLOBAL_7ZIP_EXE $sevenZipArguments | Out-Null
}

Function Write-ESSystemsConfig {
    param(
        [String] $ConfigFile,
        [hashtable] $Systems,
        [string] $RomsPath
    )

    $xmlWriter = New-Object System.XMl.XmlTextWriter($ConfigFile, $Null)
    $xmlWriter.Formatting = 'Indented'
    $xmlWriter.Indentation = 1
    $XmlWriter.IndentChar = "`t"
    $xmlWriter.WriteStartDocument()
    $xmlWriter.WriteStartElement('systemList')
    
    foreach ($item in $Systems.GetEnumerator()) {
        $xmlWriter.WriteStartElement('system')
        $xmlWriter.WriteElementString('name', $item.Key)
        $xmlWriter.WriteElementString('fullname', $item.Value[0])
        $xmlWriter.WriteElementString('path', "$RomsPath/" + $item.Key)
        $xmlWriter.WriteElementString('extension', $item.Value[1])
        $xmlWriter.WriteElementString('command', $item.Value[2])
        $xmlWriter.WriteElementString('platform', $item.Value[3])
        $xmlWriter.WriteElementString('theme', $item.Value[4])
        $xmlWriter.WriteEndElement()
    }
    $xmlWriter.WriteEndElement()
    $xmlWriter.WriteEndDocument()
    $xmlWriter.Flush()
    $xmlWriter.Close()
}

Function Add-Shortcut {
    param (
        [String]$ShortcutLocation,
        [String]$ShortcutTarget,
        [String]$ShortcutIcon,
        [String]$WorkingDir
    )
    $wshshell = New-Object -ComObject WScript.Shell
    $link = $wshshell.CreateShortcut($ShortcutLocation)
    $link.TargetPath = $ShortcutTarget
    if (-Not [String]::IsNullOrEmpty($WorkingDir)) {
        $link.WorkingDirectory = $WorkingDir
    }
    if (-Not [String]::IsNullOrEmpty($ShortcutIcon)) {
        $link.IconLocation = $ShortcutIcon
    }
    $link.Save() 
}

Function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}