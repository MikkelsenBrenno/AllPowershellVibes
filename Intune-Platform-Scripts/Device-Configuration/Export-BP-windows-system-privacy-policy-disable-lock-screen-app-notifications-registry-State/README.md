# Windows System Privacy Policy DisableLockScreenAppNotifications Registry

## Summary

Exports a local Windows System Privacy Policy DisableLockScreenAppNotifications registry policy troubleshooting snapshot for technician troubleshooting.

## File

- `Export-BP-windows-system-privacy-policy-disable-lock-screen-app-notifications-registry-State.ps1`

## What To Change First

Open the script and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `$OutputRoot` | Folder where JSON output is written. | `C:\ProgramData\IntuneScriptLibrary\Inventory` |
| `$OutputFileName` | Output file name. | `BPPlatformsystemprivacydisablelockscreenappnotificationsRegistrySnapshot.json` |
| `$CollectionMode` | Collection mode used by this script. | `Registry` |
| `$RegistryItems` | Registry paths and value names to export. | Package-specific |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Intune Management Extension installed.
- PowerShell 5.1.
- System context recommended.
- 64-bit PowerShell recommended for native Windows paths and HKLM registry state.

## Customization

Update the `CONFIGURATION` section in the script before deployment. Keep output paths, registry values, service names, event IDs, task filters, and folder paths near the top so technicians can customize quickly.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Export-BP-windows-system-privacy-policy-disable-lock-screen-app-notifications-registry-State.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

1. Go to Intune admin center.
2. Open **Devices > Manage devices > Scripts and remediations > Platform scripts**.
3. Add a Windows 10 and later PowerShell script.
4. Upload the script.
5. Choose the settings above.
6. Assign to a pilot group.

## Expected Results

- The script exits `0` when the JSON snapshot is written.
- The output file is created under the configured `$OutputRoot`.
- Logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-BP-windows-system-privacy-policy-disable-lock-screen-app-notifications-registry-State`.

## Troubleshooting

- Review the script log under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-BP-windows-system-privacy-policy-disable-lock-screen-app-notifications-registry-State`.
- Confirm the script context can write to `$OutputRoot`.
- Confirm the configured services, event logs, registry paths, scheduled tasks, or folders exist on the target Windows version.
- Rerun in 64-bit PowerShell if native HKLM or System32 data appears missing.

## Source Inspiration

Original implementation for this repository. Topic inspiration comes from public Intune and remediation libraries including [JayRHa/EndpointAnalyticsRemediationScripts](https://github.com/JayRHa/EndpointAnalyticsRemediationScripts), [MSEndpointMgr/ProactiveRemediations](https://github.com/MSEndpointMgr/ProactiveRemediations), [microsoft/intune-tenant-doc](https://github.com/microsoft/intune-tenant-doc), [MicrosoftDocs/memdocs](https://github.com/MicrosoftDocs/memdocs), and Microsoft Intune platform script guidance.


