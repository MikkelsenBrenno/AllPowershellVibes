# Ensure Windows Consumer Features Disabled

## Summary

Detects and remediates Windows Cloud Content policy that disables consumer features on managed business endpoints.

## Files

- `Detect.ps1` - Checks the current state.
- `Remediate.ps1` - Fixes the issue when detection exits `1`.

## What To Change First

Open both scripts and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `$RegistryValues` | Registry values to validate and enforce. | Package-specific |
| `$ValidationDelaySeconds` | Wait time before remediation validation. | `2` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Intune Remediations licensing and permissions.
- PowerShell 5.1.
- System context required for native HKLM policy paths.
- 64-bit PowerShell recommended for native Windows registry and service state.

## Customization

Update the `CONFIGURATION` section in both scripts before deployment. Keep service names, registry paths, expected values, safety toggles, and validation timing near the top so technicians can customize quickly.

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
7. Assign to a small pilot group before broad deployment.

## Expected Results

- Detection exits `0` when all configured registry values match.
- Detection exits `1` when one or more values are missing or different.
- Remediation creates missing keys, writes the configured values, and validates the final state.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Windows-Consumer-Features-Disabled`.
- Confirm the setting is available on the target Windows version.
- Confirm another Intune policy, security baseline, GPO, or third-party agent is not changing the state back.
- Review Intune Management Extension logs in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.

## Source Inspiration

Original implementation for this repository. Topic inspiration comes from public Intune and remediation libraries including [JayRHa/EndpointAnalyticsRemediationScripts](https://github.com/JayRHa/EndpointAnalyticsRemediationScripts), [MSEndpointMgr/ProactiveRemediations](https://github.com/MSEndpointMgr/ProactiveRemediations), [microsoft/intune-tenant-doc](https://github.com/microsoft/intune-tenant-doc), [MicrosoftDocs/memdocs](https://github.com/MicrosoftDocs/memdocs), and Microsoft Intune Remediations documentation.

