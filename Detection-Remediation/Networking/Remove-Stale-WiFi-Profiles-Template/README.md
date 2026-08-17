# Remove Stale WiFi Profiles Template

## Summary

Detects saved Wi-Fi profiles that are not in an allowed list and optionally removes them after an admin enables the safety toggle.

## Files

- `Detect.ps1` - Checks the current state.
- `Remediate.ps1` - Fixes or reports the issue when detection exits `1`.

## What To Change First

Open both scripts and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `$AllowedProfileNames` | Exact Wi-Fi profile names that should remain. | `Contoso WiFi` |
| `$AllowedProfilePrefixes` | Allowed profile name prefixes. | `CORP-` |
| `$RemoveStaleProfiles` | Safety toggle that enables deletion. | `$false` |
| `$ValidationDelaySeconds` | Wait time before remediation validation. | `2` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Wi-Fi-capable Windows devices.
- PowerShell 5.1.
- System context.
- Confirm approved corporate Wi-Fi profile names before enabling deletion.

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

- Detection exits `0` when only allowed Wi-Fi profiles exist.
- Detection exits `1` when one or more unapproved profiles are found.
- Remediation reports stale profiles by default and removes them only after `$RemoveStaleProfiles` is set to `$true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Remove-Stale-WiFi-Profiles-Template`.
- Localized Windows builds can change `netsh` output text; test parsing before broad deployment.
- Confirm the allowed list includes guest, onboarding, and VPN-prelogon Wi-Fi profiles if those should remain.

## Source Inspiration

Original implementation for this repository. Topic inspiration comes from saved Wi-Fi cleanup examples in [JayRHa/EndpointAnalyticsRemediationScripts](https://github.com/JayRHa/EndpointAnalyticsRemediationScripts) and other public Intune remediation libraries.

