#Require -Version 5.0
using namespace System.IO

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [String]
    $InstallDir,

    [Parameter()]
    [String]
    $CustomRomsFolder
)

. (Join-Path $PSScriptRoot functions.ps1)

Write-Host -ForegroundColor Magenta "************************************"
Write-Host -ForegroundColor White   "WINDOWS EMULATION STATION EASY SETUP"
Write-Host -ForegroundColor Magenta "************************************"
try {
    # #############################################################################
    # SETUP BASIC STUFF
    # #############################################################################
    Write-Host -ForegroundColor DarkYellow "SETTING UP REQUIRED PATHS"
    # Setup some basic directories and stuff
    Write-Host "INFO: Running from $PSScriptRoot"
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Write-Host "INFO: Install directory is $InstallDir"
    # Create a folder for caching downloads
    $CacheFolder = [Path]::Combine("$PSScriptRoot", ".cache")
    Write-Host "INFO: Cache directory is: $CacheFolder"
    New-Item -ItemType Directory -Force -Path $CacheFolder | Out-Null
    $ESRootFolder = [Path]::Combine($InstallDir, "EmulationStation")
    Write-Host "INFO: EmulationStation root directory is $ESRootFolder"
    $ESDataFolder = [Path]::Combine($ESRootFolder, ".emulationstation")
    Write-Host "INFO: EmulationStation data directory is $ESDataFolder"
    $ToolsFolder = [Path]::Combine($InstallDir, "tools")
    Write-Host "INFO: Additional tools directory is $ToolsFolder"

    # 7-zip
    if (!(Get-MyModule -name "7Zip4Powershell")) { 
        Write-Host -ForegroundColor Cyan "Installing required 7zip module in Powershell"
        Install-Module -Name "7Zip4Powershell" -Scope CurrentUser -Force 
    }
    $sevenZipPath = "$CacheFolder\7z\"
    Invoke-WebRequest "https://www.7-zip.org/a/7z2301-x64.exe" -Out "$CacheFolder\7z2301-x64.exe"
    Expand-7Zip -ArchiveFileName "$CacheFolder\7z2301-x64.exe" -TargetPath $sevenZipPath
    $GLOBAL_7ZIP_EXE = "$($sevenZipPath)7z.exe"
    Write-Host "INFO: 7zip executable installed to $GLOBAL_7ZIP_EXE"

    # Determine the ROMs directory
    if ([String]::IsNullOrEmpty($CustomRomsFolder)) {
        $RomsFolder = [Path]::Combine($ESDataFolder, "roms")
        New-Item -ItemType Directory -Force -Path $RomsFolder | Out-Null
    }
    else {
        if (-Not (Test-Path -Path $CustomRomsFolder)) {
            Write-Host "INFO: Custom ROMs folder $CustomRomsFolder does not exist. Creating it."
            New-Item -ItemType Directory -Force -Path $CustomRomsFolder | Out-Null
        }
        $RomsFolder = $CustomRomsFolder
    }
    Write-Host "INFO: ROMs directory is $RomsFolder"

    # Set the files that will be downloaded in each section
    # You can take a look at the "downloads" folder to see which downloads are configured
    $downloadsFolder = [Path]::Combine("$PSScriptRoot", "downloads")
    Write-Host "INFO: Downloads directory is: $downloadsFolder."
    $downloads = @{ 
        Core    = [Path]::Combine($downloadsFolder, "core.json") ; 
        Systems = [Path]::Combine($downloadsFolder, "systems.json") ; 
        Themes  = [Path]::Combine($downloadsFolder, "themes.json") ; 
        Bios    = [Path]::Combine($downloadsFolder, "bios.json") ; 
        Lrcores = [Path]::Combine($downloadsFolder, "lr-cores.json") ; 
        Tools   = [Path]::Combine($downloadsFolder, "tools.json") ;
        Games   = [Path]::Combine($downloadsFolder, "games") ;
    }

    # #############################################################################
    # ## CORE SOFTWARE (EmulationStation)
    # #############################################################################
    Write-Host -ForegroundColor DarkYellow "INSTALLING CORE SOFTWARE"
    Write-Host -ForegroundColor DarkGreen "Downloading core software from $($downloads.Core)"
    Get-RemoteFiles $downloads.Core $CacheFolder $ESRootFolder 

    # #############################################################################
    # ## SYSTEMS
    # #############################################################################
    Write-Host -ForegroundColor DarkYellow "INSTALLING SYSTEMS (EMULATORS)"
    $ESSystemsPath = [Path]::Combine($ESDataFolder, "systems")
    Write-Host "INFO: EmulationStation systems (emulators) directory is $ESSystemsPath"

    Write-Host -ForegroundColor DarkGreen "Downloading Systems software from $($downloads.Systems) to $CacheFolder"
    Get-RemoteFiles $downloads.Systems $CacheFolder $ESSystemsPath

    # #############################################################################
    # ## THEMES
    # #############################################################################
    Write-Host -ForegroundColor DarkYellow "INSTALLING ES THEMES"
    $ESThemesPath = [Path]::Combine($ESDataFolder, "themes")
    Write-Host "INFO: EmulationStation themes directory is $ESThemesPath"

    Write-Host -ForegroundColor DarkGreen "Downloading ES themes from $($downloads.Themes) to $CacheFolder"
    Get-RemoteFiles $downloads.Themes $CacheFolder $ESThemesPath

    # #############################################################################
    # ## BIOS
    # #############################################################################
    Write-Host -ForegroundColor DarkYellow "INSTALLING BIOS"
    $ESBiosPath = [Path]::Combine($ESSystemsPath, "retroarch", "system")
    Write-Host "INFO: EmulationStation Bios directory is $ESBiosPath"

    Write-Host -ForegroundColor DarkGreen "Downloading ES Bios files from $($downloads.Bios) to $CacheFolder"
    Get-RemoteFiles $downloads.Bios $CacheFolder $ESBiosPath

    # #############################################################################
    # ## SYSTEMS CONFIGURATION
    # #############################################################################
    Write-Host -ForegroundColor DarkYellow "CONFIGURING SYSTEMS"
    # RETROARCH system configuration
    $retroArchInstallPath = [Path]::Combine($ESSystemsPath, "retroarch")
    $retroarchExecutable = [Path]::Combine($retroArchInstallPath, "retroarch.exe")
    $retroarchConfigPath = [Path]::Combine($retroArchInstallPath, "retroarch.cfg")

    # Installing libretro cores
    Write-Host -ForegroundColor DarkGreen "Downloading libretro cores from: $($downloads.Lrcores)"
    $retroArchCoresPath = [Path]::Combine($retroArchInstallPath, "cores");
    Get-RemoteFiles $downloads.Lrcores $CacheFolder $retroArchCoresPath

    # Start Retroarch and generate a config.
    if (Test-Path $retroarchExecutable) {
    
        Write-Host "Retroarch executable found, launching"
        Start-Process $retroarchExecutable
    
        while (!(Test-Path $retroarchConfigPath)) { 
            Write-Host "Checking for retroarch config file $retroarchConfigPath"
            Start-Sleep 5
        }

        $retroarchProcess = Get-Process -Name "*retroarch*" -Verbose
        if ($retroarchProcess) {
            $retroarchProcess.CloseMainWindow()
            Start-sleep 5
            if (!$retroarchProcess.HasExited) {
                $retroarchProcess | Stop-Process -Force
            }
        }

    }
    else {
        Write-Host -ForegroundColor Red "ERROR: Could not find $retroarchExecutable"
        exit -1
    }

    # Tweak retroarch config!
    Write-Host -ForegroundColor Cyan "Replacing RetroArch config"
    $settingToFind = 'video_fullscreen = "false"'
    $settingToSet = 'video_fullscreen = "true"'
    (Get-Content $retroarchConfigPath) -replace $settingToFind, $settingToSet | Set-Content $retroarchConfigPath

    $settingToFind = 'savestate_auto_load = "false"'
    $settingToSet = 'savestate_auto_load = "true"'
    (Get-Content $retroarchConfigPath) -replace $settingToFind, $settingToSet | Set-Content $retroarchConfigPath

    $settingToFind = 'input_player1_analog_dpad_mode = "0"'
    $settingToSet = 'input_player1_analog_dpad_mode = "1"'
    (Get-Content $retroarchConfigPath) -replace $settingToFind, $settingToSet | Set-Content $retroarchConfigPath

    $settingToFind = 'input_player2_analog_dpad_mode = "0"'
    $settingToSet = 'input_player2_analog_dpad_mode = "1"'
    (Get-Content $retroarchConfigPath) -replace $settingToFind, $settingToSet | Set-Content $retroarchConfigPath

    # DOLPHIN system configuration
    $dolphinBinary = "$ESSystemsPath/dolphin/Dolphin.exe"
    Write-Host -ForegroundColor Cyan "Generating Dolphin Config"
    New-Item -Path "$ESSystemsPath/dolphin/portable.txt" -ItemType File -Force | Out-Null
    New-Item -Path "$ESSystemsPath/dolphin/User/Config" -ItemType Directory -Force | Out-Null
    $dolphinConfigFile = "$ESSystemsPath/dolphin/User/Config/Dolphin.ini"
    $newDolphinConfigFile = [Path]::Combine($PSScriptRoot, "configs", "Dolphin.ini")
    Copy-Item -Path $newDolphinConfigFile -Destination $dolphinConfigFile -Force
    (Get-Content $dolphinConfigFile) -replace "{ESSystemsPath}", $ESSystemsPath | Set-Content $dolphinConfigFile

    # EMULATION STATION CONFIGURATION
    # Set EmulationStation available systems (es_systems.cfg)
    $ESSystemsConfigPath = "$ESDataFolder/es_systems.cfg"
    Write-Host -ForegroundColor Cyan "Setting up EmulationStation Systems Config at $ESSystemsConfigPath"
    $systems = @{
        "amiga500"     = @("Amiga", ".adf .ADF", "$retroarchExecutable -L $retroArchCoresPath\puae_libretro.dll %ROM%", "amiga", "amiga500");
        "amigacdtv"    = @("Amiga", ".adf .ADF", "$retroarchExecutable -L $retroArchCoresPath\puae_libretro.dll %ROM%", "amiga", "amigacdtv");
        "amiga600"     = @("Amiga", ".adf .ADF", "$retroarchExecutable -L $retroArchCoresPath\puae_libretro.dll %ROM%", "amiga", "amiga600");    
        "amiga1200"    = @("Amiga", ".adf .ADF", "$retroarchExecutable -L $retroArchCoresPath\puae_libretro.dll %ROM%", "amiga", "amiga1200");
        "amigacd32"    = @("Amiga", ".adf .ADF", "$retroarchExecutable -L $retroArchCoresPath\puae_libretro.dll %ROM%", "amiga", "amigacd32");
        "atari2600"    = @("Atari 2600", ".a26 .bin .rom .A26 .BIN .ROM", "$retroarchExecutable -L $retroArchCoresPath\stella_libretro.dll %ROM%", "atari2600", "atari2600");
        "atari7800"    = @("Atari 7800 Prosystem", ".a78 .bin .A78 .BIN", "$retroarchExecutable -L $retroArchCoresPath\prosystem_libretro.dll %ROM%", "atari7800", "atari7800");
        "c64"          = @("Commodore 64", ".crt .d64 .g64 .t64 .tap .x64 .zip .CRT .D64 .G64 .T64 .TAP .X64 .ZIP", "$retroarchExecutable -L $retroArchCoresPath\vice_x64_libretro.dll %ROM%", "c64", "c64");
        "coleco"       = @("Colecovision", ".col .cv .bin .rom", "$retroarchExecutable -L $retroArchCoresPath\gearcoleco_libretro.dll %ROM%", "colecovision", "colecovision");
        "fba"          = @("Final Burn Alpha", ".zip .ZIP .fba .FBA", "$retroarchExecutable -L $retroArchCoresPath\fbalpha2012_libretro.dll %ROM%", "arcade", "");
        "gb"           = @("Game Boy", ".gb .zip .ZIP .7z", "$retroarchExecutable -L $retroArchCoresPath\gambatte_libretro.dll %ROM%", "gb", "gb");
        "gba"          = @("Game Boy Advance", ".gba .GBA", "$retroarchExecutable -L $retroArchCoresPath\vba_next_libretro.dll %ROM%", "gba", "gba");
        "gbc"          = @("Game Boy Color", ".gbc .GBC .zip .ZIP", "$retroarchExecutable -L $retroArchCoresPath\gambatte_libretro.dll %ROM%", "gbc", "gbc");
        "gc"           = @("Gamecube", ".iso .ISO", "$dolphinBinary -e `"%ROM_RAW%`"", "gc", "gc");
        "mame"         = @("MAME", ".zip .ZIP", "$retroarchExecutable -L $retroArchCoresPath\hbmame_libretro.dll %ROM%", "mame", "mame");
        "mastersystem" = @("Sega Master System", ".bin .sms .zip .BIN .SMS .ZIP", "$retroarchExecutable -L $retroArchCoresPath\genesis_plus_gx_libretro.dll %ROM%", "mastersystem", "mastersystem");
        "megadrive"    = @("Sega Mega Drive / Genesis", ".smd .SMD .bin .BIN .gen .GEN .md .MD .zip .ZIP", "$retroarchExecutable -L $retroArchCoresPath\genesis_plus_gx_libretro.dll %ROM%", "genesis,megadrive", "megadrive");
        "msx"          = @("MSX", ".col .dsk .mx1 .mx2 .rom .COL .DSK .MX1 .MX2 .ROM", "$retroarchExecutable -L $retroArchCoresPath\fmsx_libretro.dll %ROM%", "msx", "msx");
        "n64"          = @("Nintendo 64", ".z64 .Z64 .n64 .N64 .v64 .V64", "$retroarchExecutable -L $retroArchCoresPath\parallel_n64_libretro.dll %ROM%", "n64", "n64");
        "neogeo"       = @("Neo Geo", ".zip .ZIP", "$retroarchExecutable -L $retroArchCoresPath\fbalpha2012_libretro.dll %ROM%", "neogeo", "neogeo");
        "nes"          = @("Nintendo Entertainment System", ".nes .NES", "$retroarchExecutable -L $retroArchCoresPath\fceumm_libretro.dll %ROM%", "nes", "nes");
        "ngp"          = @("Neo Geo Pocket", ".ngp .ngc .zip .ZIP", "$retroarchExecutable -L $retroArchCoresPath\race_libretro.dll %ROM%", "ngp", "ngp");
        "ps2"          = @("Playstation 2", ".iso .img .bin .mdf .z .z2 .bz2 .dump .cso .ima .gz", "${ps2Binary} %ROM% --fullscreen --nogui", "ps2", "ps2");
        "psx"          = @("Playstation", ".cue .iso .pbp .CUE .ISO .PBP", "${psxEmulatorPath}ePSXe.exe -bios ${psxBiosPath}SCPH1001.BIN -nogui -loadbin %ROM%", "psx", "psx");
        "scummvm"      = @("ScummVM", ".bat .BAT", "%ROM%", "pc", "scummvm");
        "snes"         = @("Super Nintendo", ".smc .sfc .fig .swc .SMC .SFC .FIG .SWC", "$retroarchExecutable -L $retroArchCoresPath\snes9x_libretro.dll %ROM%", "snes", "snes");
        "wii"          = @("Nintendo Wii", ".iso .ISO .wad .WAD", "$dolphinBinary -e `"%ROM_RAW%`"", "wii", "wii");
        "wiiu"         = @("Nintendo Wii U", ".rpx .RPX", "START /D $cemuBinary -f -g `"%ROM_RAW%`"", "wiiu", "wiiu");
    }
    Write-ESSystemsConfig $ESSystemsConfigPath $systems $RomsFolder

    # Set EmulationStation configurations (es_settings.cfg)
    $ESSettingsFile = "$ESDataFolder\es_settings.cfg"
    Write-Host -ForegroundColor Cyan "Generating ES settings file at $ESSettingsFile"
    $newEsConfigFile = [Path]::Combine($PSScriptRoot, "configs", "es_settings.cfg")
    Copy-Item -Path $newEsConfigFile -Destination $ESSettingsFile -Force
    (Get-Content $ESSettingsFile) -replace "{ESInstallFolder}", $ESRootFolder | Set-Content $ESSettingsFile

    # Set EmulationStation default keyboard mapping (es_input.cfg)
    $esInputConfigFile = "$ESDataFolder\es_input.cfg"
    Write-Host -ForegroundColor Cyan "Setting up Emulation Station basic keyboard input at $esInputConfigFile"
    $newEsInputConfigFile = [Path]::Combine($PSScriptRoot, "configs", "es_input.cfg")
    Copy-Item -Path $newEsInputConfigFile -Destination $esInputConfigFile

    $gamesCacheFolder = $(Join-Path -Path $CacheFolder -ChildPath "games")
    & (Join-Path $PSScriptRoot updateGames.ps1) -gamesDownloads $downloads.Games -gameCacheFolder $gamesCacheFolder -RomsFolder $RomsFolder

    $toolsCacheFolder = $(Join-Path -Path $CacheFolder -ChildPath "tools")
    & (Join-Path $PSScriptRoot updateTools.ps1) -toolsDownloads $downloads.Tools -toolsCacheFolder $toolsCacheFolder -ToolsFolder $ToolsFolder

    # Add an scraper to ROMs folder
    Write-Host -ForegroundColor Cyan "Installing scraper in $RomsFolder"
    Copy-Item -Path "$ToolsFolder\scraper\scraper.exe" -Destination $RomsFolder

    # #############################################################################
    # CREATING SHORTCUTS
    # #############################################################################
    Write-Host -ForegroundColor DarkYellow "CREATING SHORTCUTS"
    $ESBatName = "launch_portable.bat"
    $ESBatWindowed = "launch_portable_windowed.bat"
    $ESIconPath = [Path]::Combine($ESRootFolder, "icon.ico")
    $ESPortableBat = [Path]::Combine($ESRootFolder, $ESBatName)
    $ESPortableWindowedBat = [Path]::Combine($ESRootFolder, $ESBatWindowed)
    if (!(Test-Path $ESPortableBat)) {
        $batContents = "set HOME=%~dp0
    emulationstation.exe"
        New-Item -Path $ESRootFolder -Name $ESBatName -ItemType File -Value $batContents | Out-Null
    }
    if (!(Test-Path $ESPortableWindowedBat)) {
        $batContents = "set HOME=%~dp0
    emulationstation.exe --resolution 960 720 --windowed"
        New-Item -Path $ESRootFolder -Name $ESBatWindowed -ItemType File -Value $batContents | Out-Null
    }

    Add-Shortcut -ShortcutLocation "$InstallDir\Roms.lnk" -ShortcutTarget $RomsFolder
    Add-Shortcut -ShortcutLocation "$InstallDir\Cores.lnk" -ShortcutTarget "$ESDataFolder\systems\retroarch\cores"
    Add-Shortcut -ShortcutLocation "$InstallDir\EmulationStation.lnk" -ShortcutTarget $ESPortableBat -ShortcutIcon $ESIconPath -WorkingDir $ESRootFolder
    Add-Shortcut -ShortcutLocation "$InstallDir\EmulationStation (Windowed).lnk" -ShortcutTarget $ESPortableWindowedBat -ShortcutIcon $ESIconPath -WorkingDir $ESRootFolder
    $desktop = [System.Environment]::GetFolderPath('Desktop')
    Add-Shortcut -ShortcutLocation "$desktop\EmulationStation.lnk" -ShortcutTarget $ESPortableBat -ShortcutIcon $ESIconPath -WorkingDir $ESRootFolder
    Add-Shortcut -ShortcutLocation "$desktop\EmulationStation (Windowed).lnk" -ShortcutTarget $ESPortableWindowedBat -ShortcutIcon $ESIconPath -WorkingDir $ESRootFolder

    Write-Host -ForegroundColor DarkYellow "FINISHED SETUP!"
}
catch { 
    Write-Error $_ 
}