# Configure Windows Update Notifications

## Summary

This platform script configures Windows Update notification display policy values. The default restores Windows default notifications by removing the policy values.

## File

- `Configure-Windows-Update-Notifications.ps1`

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$NotificationDisplayOption` | `DefaultNotifications`, `RestartWarningsOnly`, or `DisableAllNotifications`. | `DefaultNotifications` |
| `$WindowsUpdatePolicyPath` | Policy registry path. | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context required for HKLM policy values.

## Customization

Use `DisableAllNotifications` only for kiosk-style scenarios where restart behavior is tightly controlled.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Configure-Windows-Update-Notifications.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to a pilot group and confirm user notification behavior.

## Exit Codes

- `0` - Notification policy configured.
- `1` - Notification policy failed.

## Expected Results

Windows Update notifications follow the selected option.

## Troubleshooting

- Review `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Configure-Windows-Update-Notifications\Configure-Windows-Update-Notifications.log`.
- Check for conflicting Intune, GPO, or Autopatch policy.

## Common Failures

- Notifications are managed by another update policy.
- Notification suppression is assigned to non-kiosk devices.
