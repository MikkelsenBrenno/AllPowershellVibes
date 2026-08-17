# Defender Enable Email Scanning

## Summary

Detects and remediates Microsoft Defender email scanning by keeping `DisableEmailScanning` set to `$false`.

## Files

- `Detect.ps1` - Checks the current state.
- `Remediate.ps1` - Fixes or reports the issue when detection exits `1`.

## What To Change First

Open both scripts and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `$PreferenceName` | Defender preference property checked and remediated. | Package-specific |
| `$DesiredValue` | Desired boolean value for the Defender preference. | `$false` |
| `$FriendlySettingName` | Human-readable name shown in logs and output. | Package-specific |
| `$ValidationDelaySeconds` | Wait time before remediation validation. | `3` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Defender Antivirus available on the target device.
- PowerShell 5.1.
- System context recommended.
- 64-bit PowerShell recommended.

## Customization

Update the `CONFIGURATION` section in both scripts before deployment. Keep tenant-specific values, paths, profile names, and safety toggles near the top so technicians can review them immediately.

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
7. Assign to a small pilot group first.

## Expected Results

- Detection exits `0` when the Defender preference matches the configured value.
- Detection exits `1` when the setting is missing, different, or unavailable.
- Remediation sets the preference through `Set-MpPreference` and validates the final value.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\<ScriptPackageName>`.
- Confirm Defender PowerShell cmdlets exist on the device.
- Check whether Intune Endpoint Security, a security baseline, or another policy controls the same Defender setting.
- Pilot carefully when moving a setting from audit/reporting to enforced behavior.

## Source Inspiration

Original implementation for this repository. Topic inspiration comes from public Intune remediation libraries such as [JayRHa/EndpointAnalyticsRemediationScripts](https://github.com/JayRHa/EndpointAnalyticsRemediationScripts), [aaronparker/intune](https://github.com/aaronparker/intune), and Microsoft Defender configuration guidance in [MicrosoftDocs/memdocs](https://github.com/MicrosoftDocs/memdocs).

