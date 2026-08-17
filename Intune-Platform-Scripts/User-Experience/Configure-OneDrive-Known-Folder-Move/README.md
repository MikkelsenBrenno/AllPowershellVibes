# Configure OneDrive Known Folder Move

## Summary

This platform script configures OneDrive Known Folder Move policy values for prompting users or silently moving known folders.

## Files

- `Configure-OneDrive-Known-Folder-Move.ps1` - Writes OneDrive KFM policy registry values when enabled.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$TenantId` | Microsoft Entra tenant ID used by OneDrive KFM policy. | Placeholder GUID |
| `$KfmMode` | `Prompt` or `Silent`. | `Prompt` |
| `$PreventUsersFromOptingOut` | Set `KFMBlockOptOut`. | `$true` |
| `$ApplyPolicy` | Actually write policy values. | `$false` |
| `$OneDrivePolicyRoot` | OneDrive policy registry path. | `HKLM:\SOFTWARE\Policies\Microsoft\OneDrive` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- OneDrive sync client deployed.
- System context recommended for HKLM policy.

## Customization

Replace `$TenantId` with your real tenant ID and pilot `Prompt` mode before using `Silent` mode.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Configure-OneDrive-Known-Folder-Move.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to a pilot group first. Confirm OneDrive sync health and user experience before broad deployment.

## Exit Codes

- `0` - Policy was applied or reporting-only success is enabled.
- `1` - Policy was not applied.

## Expected Results

The OneDrive KFM policy values are present under `HKLM:\SOFTWARE\Policies\Microsoft\OneDrive`.

## What Success Looks Like

- Prompt mode writes `KFMOptInWithWizard`.
- Silent mode writes `KFMOptInNoWizard`.
- Logs exist under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Configure-OneDrive-Known-Folder-Move`.

## Troubleshooting

- Confirm `$TenantId` is not the placeholder GUID.
- Confirm OneDrive is installed and signed in for the user.
- Review OneDrive sync client policy state.

## Common Failures

- `$ApplyPolicy` is still disabled.
- The tenant ID is wrong.
- A different OneDrive policy blocks KFM.
