# utacore

An UTAU voicebank installer gui inspired by the VOCALOID voicebank installers!! (but with cool extra features!!!)

# UTACORE

UTACORE is a Windows GUI tool for building reusable `.exe` installers for UTAU voicebanks.

## Features

- Build voicebank installer executables from a simple GUI
- Optional intro video screen
- Optional terms of service screen from a `.txt` file
- Custom installer accent color
- Character image and voicebank information display
- User-selectable install path with folder browser
- Extracts the packaged voicebank into its own folder inside the chosen location

## Included Files

- `UTACORE.ps1`
- `Launch-UTACORE.bat`
- `Launch-UTACORE.vbs`
- `UTACORE.png`
- `UTACORE.ico`
- `README.md`

## Requirements

- Windows
- PowerShell
- `IExpress` (included with Windows)

## Usage

1. Run `Launch-UTACORE.bat`
2. Select the voicebank `.zip`
3. Select the character image
4. Optionally add an intro video
5. Optionally add a terms of service `.txt`
6. Fill in the voicebank information
7. Choose where to save the finished installer `.exe`
8. Click `Build Installer EXE`

## Repository Notes

- The generated installer is intended for Windows distribution.
- Keep the UTACORE launcher, script, image, and icon files together in the same folder.
- Example build outputs and temporary files should not be committed to the repository.
