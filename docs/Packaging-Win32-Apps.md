# Packaging Win32 Apps

PowerShell scripts can be packaged as Win32 apps when you need install, uninstall, detection, assignments, dependencies, supersedence, or Company Portal behavior.

## Recommended Package Folder

Keep each packaged script self-contained:

```text
Win32-Packaged-Scripts/
`-- Device-Configuration/
    `-- Example-Install-Registry-Setting/
        |-- Install.ps1
        |-- Uninstall.ps1
        |-- Detect.ps1
        `-- README.md
```

## Create the Package

Download the Microsoft Win32 Content Prep Tool and run it against the package folder.

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\Device-Configuration\Example-Install-Registry-Setting" -s "Install.ps1" -o ".\PackageOutput"
```

This creates an `.intunewin` file that can be uploaded to Intune.

## Install Command

Use this command when you need 64-bit Windows PowerShell:

```text
%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1
```

## Uninstall Command

```text
%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

## Detection Rules

For PowerShell detection:

- Select custom detection script.
- Upload `Detect.ps1`.
- Detection succeeds when the script exits `0` and writes a string to STDOUT.
- Detection fails when the script exits nonzero.
- Use 64-bit detection for native HKLM and system path checks.

## Install Behavior

Choose system context for machine-wide changes. Choose user context only for user-profile or HKCU changes.

## Return Codes

Keep return codes simple unless you need vendor-specific handling:

| Code | Meaning |
| --- | --- |
| `0` | Success |
| `1` | Failure |
| `3010` | Success, reboot required |
| `1641` | Success, reboot initiated |

## Practical Tips

- Package only the files required for install, uninstall, and detection.
- Avoid downloading from the internet during install unless your organization explicitly allows it.
- Keep install and uninstall idempotent, meaning they can run more than once safely.
- Make detection check the actual installed state, not only a log file.
- Store logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\<ScriptPackageName>\<ScriptName>.log`.
