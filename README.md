# EmulationStation configuration script for Windows 11

![Script working](https://github.com/ferarias/emustation-winsetup/workflows/Build/badge.svg)

An auto-installer to set up a **portable** installation of [Emulation Station](http://www.emulationstation.org) on a 64-bit version of Windows 11.

## Features

- Based upon the fabulous work by [Francommit](https://github.com/Francommit) in the [original version](https://github.com/Francommit/win10_emulation_station).
- Uses an up to date version of Emulation Station
- Sets up some sensible configurations
- Adds some free roms
- Adds a custom theme 
- Adds shortcuts to Desktop
- Adds a game scraper to roms folder

## Steps

### Option A. Easy setup:

Easy install by copying the following text and pasting it into a Microsoft Powershell window.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force;[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;$tag = (Invoke-WebRequest "https://api.github.com/repos/ferarias/emustation-winsetup/releases" -UseBasicParsing | ConvertFrom-Json)[0].tag_name;Invoke-WebRequest "https://github.com/ferarias/emustation-winsetup/archive/$tag.zip" -OutFile "ESSetup.zip";Expand-Archive .\ESSetup.zip;Move-Item .\ESSetup\win* .\ESSetup\setup;.\ESSetup\setup\install.ps1
```

### Option B. Detailed steps (recommended)

- Download the [Latest Release](https://github.com/ferarias/emustation-winsetup/releases/latest) (Source code zip or tgz)
- Extract to a convenient folder. E.g.: `c:\tmp`
- Start a PowerShell and move to the extracted directory
- You can run the installation process using the `.\install.ps1` script. The syntax is as follows:  
```powershell
.\install.ps1 [-InstallDir] <string> [[-CustomRomsFolder] <string>] [<CommonParameters>]
```
Example:  
```powershell
.\install.ps1 C:\emu
```
If you already have a folder with ROM files, use the second parameter to specify it. For example:

```powershell
.\install.ps1 -InstallDir C:\emu -CustomRomsFolder C:\Users\ferarias\roms
```

Script has completed when Powershell spits out:

```powershell
FINISHED SETUP!
```

## Running

1. Double-click the `EmulationStation` shortcut to launch
2. To access your ROMS follow the shortcut named `Roms` in the installation folder.
3. To access your RetroArch cores follow the shortcut named `Cores` in the installation folder.
4. If you want to open EmulationStation *in a window* instead of fullscreen, double-click the `EmulationStation (Windowed)` shortcut.

## Troubleshooting

- _Controller is not working in games_: configure Input in Retroarch (in EmulationStation\\.emulationstation\systems\retroarch\retroarch.exe)
- _PSX and PS2 Homebrew Games don't work_: they won't load unless you acquire the bios's and add them to the bios folder (EmulationStation\\.emulationstation\systems\epsxe\bios and EmulationStation\\.emulationstation\systems\pcsx2\bios).  
  PSX and PS2 also require manual configuration for controllers (EmulationStation\\.emulationstation\systems\epsxe\ePSXe.exe and EmulationStation\.emulationstation\systems\pcsx2\pcsx2.exe)
- _Script fails_: if the script fails for whatever reason, delete the contents of EmulationStation\\.emulationstation and try again.  
  Ensure you are using Microsoft Powershell and not Windows Powershell and that your Powershell session is in Admin mode.
- If you are using Xbox controllers and having trouble setting the guide button as hotkey, locate the file (EmulationStation\\.emulationstation\es_input.cfg and change the line for hotkeyenable to ```<input id="5" name="hotkeyenable" type="button" value="10" />```

## Uninstall

There's an uninstall script, also:

```powershell
.\uninstall.ps1 -InstallDir C:\em   
```

## Special Thanks

- [Francommit](https://github.com/Francommit) for the [original version](https://github.com/Francommit/win10_emulation_station) of the scripts.
- [RetroBat](https://github.com/RetroBat-Official/) for his up to date [compiled version of Emulation Station](https://github.com/RetroBat-Official/EmulationStation).
- [Dream17](http://dream17.abime.net) for their great Amiga Games
- [Nesworld](http://www.nesworld.com/) for their open-source NES roms.
- [Libretro](https://www.libretro.com/) for their RetroArch version.
- [OpenEmu](https://github.com/OpenEmu/) for their [Open-Source rom collection](https://github.com/OpenEmu/OpenEmu-Update) work.
- [fonic](https://github.com/fonic/) for his [recalbox-backport theme](https://github.com/fonic/recalbox-backport).
- [sselph](https://github.com/sselph/scraper) and [muldjord](https://github.com/muldjord/skyscraper) for their scrapers.
