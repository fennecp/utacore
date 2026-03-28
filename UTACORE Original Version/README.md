# UTACORE

Please do not redistribute UTACORE or claim that you made the software!!
If you have paid for this software you have been scammed, this is a free software for everyone.
UTACORE is made by fennecP

UTACORE is a Windows GUI tool for building reusable `.exe` installers for UTAU voicebanks.

## What it does

The maker app lets you choose:

- the compressed voicebank folder as a `.zip`
- a character image
- an optional intro video
- an optional terms of service `.txt` file
- the displayed voicebank name, character name, creator, and description
- an optional custom accent color for the installer UI
- where to save the finished installer `.exe`

The generated installer `.exe`:

- can open with an autoplay intro video
- can show a terms of service screen with `Agree` and `Disagree`
- moves into the installer screen after the optional intro and optional terms flow
- shows the character art and voicebank information
- lets the user edit the destination folder path
- includes a `Browse...` button to choose a folder in Windows Explorer
- extracts the uploaded `.zip` into a voicebank subfolder inside the selected folder while preserving the zip's internal folder tree

## How to use it

1. Put your voicebank into a `.zip` file.
2. Run `Launch-UTACORE.bat`.
3. Fill in the GUI fields.
4. Click `Build Installer EXE`.
5. Share the produced `.exe`.

## Notes

- The builder uses Windows `IExpress`, which is built into Windows.
- If you use the optional intro video, it should be a format Windows Media playback can open, such as `.mp4` or `.wmv`.
- The voicebank archive is extracted with PowerShell `Expand-Archive`, so the folder structure inside the `.zip` is preserved exactly.
- Keep `UTACORE.ps1`, `Launch-UTACORE.bat`, `Launch-UTACORE.vbs`, `UTACORE.png`, and `UTACORE.ico` together in the same folder.
