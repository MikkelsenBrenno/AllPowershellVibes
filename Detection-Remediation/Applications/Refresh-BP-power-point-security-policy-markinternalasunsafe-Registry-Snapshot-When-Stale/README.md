# PowerPoint Security Policy markinternalasunsafe Registry

## Summary

Refreshes a local PowerPoint Security Policy markinternalasunsafe registry policy troubleshooting snapshot when it is missing or stale.

## Files

- `Detect.ps1` - Checks whether the local troubleshooting snapshot exists and is current.
- `Remediate.ps1` - Refreshes the troubleshooting snapshot when detection exits `1`.

## What To Change First

Open both scripts and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `$SnapshotRoot` | Folder where remediation snapshots are written. | `C:\ProgramData\IntuneScriptLibrary\RemediationSnapshots` |
| `$SnapshotFileName` | JSON snapshot file name. | `BPofficepowerpointsecuritymarkinternalasunsafeRegistrySnapshot.json` |
| `$MaximumSnapshotAgeHours` | Maximum age before detection triggers refresh. | `24` |
| `$CollectionMode` | Collection method used by remediation. | `Registry` |
| `$RegistryItems` | Registry paths and value names collected by remediation. | Package-specific |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Intune Remediations licensing and permissions.
- PowerShell 5.1.
- System context recommended.
- 64-bit PowerShell recommended for native Windows paths, services, and HKLM registry state.

## Customization

Update the `CONFIGURATION` section in both scripts before deployment. Keep snapshot path, snapshot age, registry paths, service names, event IDs, folder paths, and task filters near the top so technicians can customize quickly.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

1. Go to Intune admin center.
2. Open **Devices > Manage devices > Scripts and remediations**.
3. Create a script package.
4. Upload `Detect.ps1` as the detection script.
5. Upload `Remediate.ps1` as the remediation script.
6. Choose the settings above.
7. Assign to a pilot group before broad deployment.

## Expected Results

- Detection exits `0` when the snapshot exists and is newer than `$MaximumSnapshotAgeHours`.
- Detection exits `1` when the snapshot is missing, stale, or unavailable.
- Remediation exits `0` after writing the JSON snapshot.
- Logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Refresh-BP-power-point-security-policy-markinternalasunsafe-Registry-Snapshot-When-Stale`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Refresh-BP-power-point-security-policy-markinternalasunsafe-Registry-Snapshot-When-Stale`.
- Confirm the script context can write to `$SnapshotRoot`.
- Confirm configured services, registry paths, event logs, scheduled tasks, or folders exist on the target Windows version.
- Rerun in 64-bit PowerShell if native HKLM or System32 data appears missing.

## Source Inspiration

Original implementation for this repository. Topic inspiration comes from public Intune and remediation libraries including [JayRHa/EndpointAnalyticsRemediationScripts](https://github.com/JayRHa/EndpointAnalyticsRemediationScripts), [MSEndpointMgr/ProactiveRemediations](https://github.com/MSEndpointMgr/ProactiveRemediations), [microsoft/intune-tenant-doc](https://github.com/microsoft/intune-tenant-doc), [MicrosoftDocs/memdocs](https://github.com/MicrosoftDocs/memdocs), and Microsoft Intune Remediations documentation.


