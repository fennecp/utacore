README updated to UTACORE v2.0 features on 3/26/2026
# UTACORE

## IMPORTANT!!!
**THE FILES IN THE MAIN REPOSITORY ARE NOT UPDATED, IT IS THE BASE VERSION OF UTACORE**
**PLEASE DOWNLOAD UTACORE FROM THE "RELEASES" PAGE IF YOU WANT THE NEW FEATURES AND BUG FIXES!!!**

## REPORT BUGS HERE
VOCACORD SERVER: https://discord.gg/QuqQSJhqUe

## ABOUT
UTACORE is a Windows desktop builder for reusable UTAU voicebank installer `.exe` files inspired by the VOCALOID voicebank installers.

It lets you package a voicebank archive, artwork, metadata, optional vocal modes, optional video screens, optional terms of service, and localized installer UI into a shareable Windows installer.

## Features

- Builds Windows installer `.exe` files from a GUI
- Optional intro video before install
- Optional terms of service screen from a `.txt` file
- Optional extra vocal modes with checkbox selection during install
- Optional thank-you voice clip screen after installation
- Localized maker and installer UI
- Custom installer accent color
- Character artwork and voicebank metadata display
- Folder browser for install destination
- Installs the main bank and optional modes into sibling folders in the selected voicebank directory
- Background music and installer animations

## Included Files

- `UTACORE.ps1`
- `Launch-UTACORE.bat`
- `Launch-UTACORE.vbs`
- `UTACORE.png`
- `UTACORE.ico`
- default bundled media assets for the installer flow

## Requirements

- Windows
- PowerShell
- `IExpress` included with Windows

## Usage

1. Run `Launch-UTACORE.bat`.
2. Choose the main voicebank `.zip`.
3. Choose the character image.
4. Optionally add an intro video, terms file, and thank-you audio.
5. Optionally add extra vocal mode `.zip` files.
6. Fill in the voicebank info fields.
7. Choose the installer output path.
8. Build the installer `.exe`.

## Installer Flow

The generated installer can include this sequence:

1. Optional intro video
2. Optional terms of service page
3. Install options page
4. Install animation page
5. Thank-you page with voice clip
6. Final completion page

## Repository Notes

- Keep the launcher, script, icon, logo, and bundled default media files together.
- Build outputs, temporary files, and sample test folders should stay out of version control.
- The distribution folder contains the clean shareable app bundle.
