# Naming Conventions

Consistent names make the repository easier to search, copy, and automate.

## Folder Names

Use descriptive folder names with words separated by hyphens:

```text
Example-Ensure-Service-Running
Check-BitLocker-Status
Set-TimeZone
Install-Registry-Setting
```

Avoid spaces, tenant names, user names, internal project codes, and unexplained abbreviations.

## Workload Folders

Use these root workload folders:

- `Detection-Remediation`
- `Custom-Compliance`
- `Intune-Platform-Scripts`
- `Win32-Packaged-Scripts`

## Purpose Category Folders

Use these shared purpose categories under each workload folder:

- `Security`
- `Compliance`
- `Device-Configuration`
- `Applications`
- `Maintenance`
- `Endpoint-Health`
- `Networking`
- `User-Experience`
- `Inventory-Reporting`
- `Windows-Updates`
- `Browser-Management`
- `Remote-Work`
- `Identity-Access`
- `Printing`
- `Certificates-PKI`
- `Hardware-Drivers`
- `Power-Battery`
- `Backup-Recovery`
- `MDM-Enrollment`
- `Data-Protection`
- `Storage-Disk`
- `Troubleshooting-Support`
- `Peripheral-Devices`
- `Licensing-Activation`

Script folders should sit under a workload and a purpose category:

```text
Detection-Remediation/Security/Defender-Enable-Network-Protection/
Intune-Platform-Scripts/Device-Configuration/Set-TimeZone/
Win32-Packaged-Scripts/Applications/Install-Example-App/
```

## Script File Names

Use standard file names when Intune expects a specific role:

| Workload | Detection | Remediation | Discovery | Install | Uninstall |
| --- | --- | --- | --- | --- | --- |
| Detection and Remediation | `Detect.ps1` | `Remediate.ps1` | N/A | N/A | N/A |
| Custom Compliance | N/A | N/A | `Discover.ps1` | N/A | N/A |
| Platform Script | N/A | N/A | N/A | N/A | N/A |
| Win32 Packaged Script | `Detect.ps1` | N/A | N/A | `Install.ps1` | `Uninstall.ps1` |

For platform scripts, use a verb-noun style name:

```text
Set-TimeZone.ps1
Configure-StartMenuPins.ps1
Remove-DesktopShortcut.ps1
```

## Configuration Names

Use clear variable names in the `CONFIGURATION` section:

```powershell
$ServiceName = 'Spooler'
$TargetTimeZoneId = 'UTC'
$RegistryPath = 'HKLM:\SOFTWARE\IntuneScriptLibrary\Example'
```

## Log Names

Logs should use a folder per script package and a log file named after the script role or script file:

```text
C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Example-Ensure-Service-Running\Detect.log
C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Example-Ensure-Service-Running\Remediate.log
C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Example-Install-Registry-Setting\Install.log
```

Set these values in every Intune script:

```powershell
$ScriptPackageName = '<FolderName>'
$ScriptName = '<ScriptFileNameWithoutExtension>'
```

The repository validation tool checks that these values match the folder and script file.

## Versioning

Use semantic versioning in script headers:

```text
1.0.0 - Initial version
1.1.0 - Backward-compatible feature
1.1.1 - Bug fix
2.0.0 - Breaking behavior change
```

## README Names

Every script folder should include `README.md`. Avoid separate deployment notes unless the script is complex enough to justify them.
