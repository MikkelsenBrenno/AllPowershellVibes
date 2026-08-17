# Win32 Packaged Scripts

Use this category when a PowerShell script should behave like an application with install, uninstall, detection, assignment, dependencies, supersedence, or Company Portal behavior.

## Folder Standard

```text
Win32-Packaged-Scripts/
`-- <Purpose-Category>/
    `-- <Package-Name>/
        |-- Install.ps1
        |-- Uninstall.ps1
        |-- Detect.ps1
        `-- README.md
```

## Purpose Categories

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

## Script Rules

- `Install.ps1` applies the desired state and validates it.
- `Uninstall.ps1` removes only what the package owns.
- `Detect.ps1` checks the installed state.
- Custom detection must exit `0` and write STDOUT when detected.
- Detection should check the real installed state, not only a log file.

## Intune Settings

Recommended defaults:

| Setting | Recommendation |
| --- | --- |
| Install behavior | System for machine-wide changes |
| Device restart behavior | No specific action unless reboot is required |
| Detection script 32-bit mode | No for native 64-bit registry or file checks |
| Install command PowerShell path | Use `Sysnative` when forcing 64-bit Windows PowerShell |

## Examples

| Folder | Purpose |
| --- | --- |
| `Device-Configuration/Example-Install-Registry-Setting` | Installs, uninstalls, and detects a registry setting |

## Add a New Win32 Packaged Script

1. Choose the correct purpose category.
2. Copy the nearest example or create a starter folder with `tools/New-IntuneScriptFolder.ps1`.
3. Update install, uninstall, and detection configuration together.
4. Package with the Microsoft Win32 Content Prep Tool.
5. Pilot with required assignment before broad deployment.
