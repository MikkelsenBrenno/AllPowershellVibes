# Ensure Registry Value

## Summary

This remediation package detects and enforces a configurable registry value.

## Files

- `Detect.ps1` - Checks the registry value.
- `Remediate.ps1` - Creates or updates the registry value.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$RegistryPath` | Registry key path to check or create. | `HKLM:\SOFTWARE\IntuneScriptLibrary\ExamplePolicy` |
| `$ValueName` | Registry value name. | `ExampleSetting` |
| `$ExpectedValueData` | Expected value in detection. | `Enabled` |
| `$ValueData` | Value written by remediation. | `Enabled` |
| `$ValueType` | Registry value type. | `String` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended for HKLM settings.
- 64-bit PowerShell recommended for native HKLM paths.

## Customization

Keep detection and remediation values aligned. Use HKCU only when deploying in user context.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No for HKLM, Yes for HKCU |
| Run script in 64-bit PowerShell | Yes for native HKLM paths |

## Intune Deployment

Deploy to a small pilot group and confirm the registry view matches the selected PowerShell bitness.

## Exit Codes

- Detection `0` - Registry value matches.
- Detection `1` - Registry value is missing or different.
- Remediation `0` - Registry value was set and validated.
- Remediation `1` - Registry value could not be set or validated.

## Expected Results

The configured registry value exists and matches the expected data.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Registry-Value`.
- Confirm 32-bit versus 64-bit registry view.
- Confirm the script context has permission to write the key.

## Common Failures

- Detection and remediation use different value data.
- HKCU is used while running as system.
- 32-bit PowerShell writes to `WOW6432Node` unexpectedly.
