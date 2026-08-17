# Example: Set Time Zone

## Summary

This platform script sets the Windows time zone to a configurable Windows time zone ID. The default example uses `UTC`.

The script uses `tzutil.exe` for Windows PowerShell 5.1 compatibility and validates the final state before exiting successfully.

## File

- `Set-TimeZone.ps1`

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Intune Management Extension installed.
- PowerShell 5.1.
- System context recommended because time zone is a device-level setting.

## Customization

Update the `CONFIGURATION` section in the script.

| Setting | Description | Default |
| --- | --- | --- |
| `$TargetTimeZoneId` | Windows time zone ID to apply. Use `tzutil.exe /l` to list valid values. | `UTC` |

Common examples:

```text
UTC
Eastern Standard Time
Central European Standard Time
GMT Standard Time
```

## Intune Deployment

1. Go to Intune admin center.
2. Open **Devices > Manage devices > Scripts and remediations > Platform scripts**.
3. Add a Windows PowerShell script.
4. Upload `Set-TimeZone.ps1`.
5. Run as system.
6. Run in 64-bit PowerShell host.
7. Assign to a pilot device group.

## Expected Results

- If the device already uses the target time zone, the script exits `0`.
- If the time zone differs, the script changes it and validates the new value.
- If validation fails, the script exits `1`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Example-Set-TimeZone\Set-TimeZone.log`.
- Confirm `$TargetTimeZoneId` exactly matches a value from `tzutil.exe /l`.
- Confirm the device is not restricted by another policy that controls time zone.
- Review Intune Management Extension logs in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
