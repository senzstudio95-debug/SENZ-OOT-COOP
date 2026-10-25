# SENZ Zelda EXE launcher v2.5.2

Native Windows x64 GUI bootstrap for the existing PowerShell/WPF launcher. Opens Launcher.ps1 beside the EXE without a console, uses a per-folder mutex, and records startup output in launcher-error.log. Does not require administrator rights. Package engine is the original SoH 9.3.1 with v2.5.1 recovery settings pre-applied.

Build using MinGW-w64. Render zelda.svg to 256px PNG and export zelda.ico at 16, 24, 32, 48, 64, 128 and 256px first.

```sh
x86_64-w64-mingw32-windres launcher.rc -O coff -o launcher.res
x86_64-w64-mingw32-gcc launcher.c launcher.res -o SENZ-Zelda.exe -municode -mwindows -Os -s -static -Wall -Wextra -Wno-unused-parameter -Werror -luser32
```

Keep the EXE with Launcher.ps1, Launcher.xaml, zelda.ico, engine and runtime directories from the full release. No batch entrypoints are used. The full ZIP contains required support files and v2.5.1 recovery; it is a portable folder, not a standalone single-file game EXE.

Validation: PE x64 GUI subsystem, icon/version/manifest resources, default DLL imports, PowerShell syntax and ValidateOnly, XAML parse, original engine hash, disabled effect defaults and ZIP CRC passed. Windows UI and gameplay not runtime-tested here.
