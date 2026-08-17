# Example: Check BitLocker Status

## Summary

This custom compliance example reports whether BitLocker is protected and fully encrypted on a configurable volume. The default volume is `C:`.

`Discover.ps1` returns compressed JSON. `ComplianceRules.json` defines the compliant values.

## Files

- `Discover.ps1` - Discovers BitLocker status and returns JSON.
- `ComplianceRules.json` - Requires `BitLockerProtected` to be `true` and `BitLockerEncryptionPercentage` to be at least `100`.

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Windows edition with BitLocker support.
- PowerShell 5.1.
- System context recommended.
- `Get-BitLockerVolume` must be available on the target device.

## Customization

Update the `CONFIGURATION` section in `Discover.ps1`.

| Setting | Description | Default |
| --- | --- | --- |
| `$MountPoint` | Volume to evaluate. | `C:` |
| `$RequiredProtectionStatus` | Required BitLocker protection status. | `On` |
| `$MinimumEncryptionPercentage` | Minimum encryption percentage. | `100` |

If you change output property names in `Discover.ps1`, update the matching `SettingName` values in `ComplianceRules.json`. Setting names are case-sensitive.

## Intune Deployment

1. Go to Intune admin center.
2. Open **Endpoint security > Device compliance > Scripts**.
3. Add `Discover.ps1` as a Windows discovery script.
4. Use system context.
5. Use 64-bit PowerShell host.
6. Create or edit a Windows compliance policy.
7. Add custom compliance settings.
8. Upload `ComplianceRules.json`.
9. Select the discovery script.
10. Assign to a pilot group.

## Expected Results

Example compliant output:

```json
{"BitLockerProtected":true,"BitLockerProtectionStatus":"On","BitLockerEncryptionPercentage":100}
```

If BitLocker is off, unavailable, or not fully encrypted, the policy evaluates as noncompliant.

## Troubleshooting

- Run `Discover.ps1` locally and confirm it returns one compressed JSON object.
- Do not add extra `Write-Output` lines to the script.
- Confirm `ComplianceRules.json` is valid JSON.
- Confirm `SettingName` values match the script output exactly.
- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Example-Check-BitLocker-Status\Discover.log`.
