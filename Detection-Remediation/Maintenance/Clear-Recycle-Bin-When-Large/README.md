# Clear Recycle Bin When Large

## Summary

Detects the signed-in user's accessible Recycle Bin usage across fixed drives and optionally clears it after an admin enables the safety toggle.

## Files

- `Detect.ps1` - Checks the current state.
- `Remediate.ps1` - Fixes or reports the issue when detection exits `1`.

## What To Change First

Open both scripts and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `$MaximumRecycleBinSizeMB` | Size threshold before detection reports noncompliance. | `2048` |
| `$ClearRecycleBin` | Safety toggle that enables deletion. | `$false` |
| `$ValidationDelaySeconds` | Wait time before remediation validation. | `3` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- User context is required so detection and `Clear-RecycleBin` evaluate the same signed-in user's state.
- Pilot carefully because this deletes user-restorable files when enabled.

## Customization

Update the `CONFIGURATION` section in both scripts before deployment. Keep tenant-specific values, paths, profile names, and safety toggles near the top so technicians can review them immediately.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | Yes |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

1. Go to Intune admin center.
2. Open **Devices > Manage devices > Scripts and remediations**.
3. Create a script package.
4. Upload `Detect.ps1` as the detection script.
5. Upload `Remediate.ps1` as the remediation script.
6. Choose the settings above.
7. Assign to a small pilot group first.

## Expected Results

- Detection exits `0` when estimated Recycle Bin usage is under the threshold.
- Detection exits `1` when usage exceeds the threshold.
- Remediation remains noncompliant while reporting and clears Recycle Bin only after `$ClearRecycleBin` is set to `$true`.
- Remediation exits `0` only after the final size is under the configured threshold.

## Troubleshooting

- Review logs in `%LOCALAPPDATA%\Microsoft\IntuneScriptLibrary\Logs\Clear-Recycle-Bin-When-Large`.
- Confirm the package is assigned in user context for the signed-in user's Recycle Bin.
- Some files can remain if locked or owned by profiles the context cannot access.

## Source Inspiration

Original implementation for this repository. Topic inspiration comes from disk cleanup and Recycle Bin maintenance examples in [JayRHa/EndpointAnalyticsRemediationScripts](https://github.com/JayRHa/EndpointAnalyticsRemediationScripts) and public Intune remediation collections.

