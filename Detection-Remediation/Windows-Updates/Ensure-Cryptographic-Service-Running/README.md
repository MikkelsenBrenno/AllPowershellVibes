# Ensure Cryptographic Service Running

## Summary

Detects and remediates devices where Cryptographic Services is stopped, which can affect Windows Update, certificates, and app installs.

## Files

- `Detect.ps1` - Checks the current state.
- `Remediate.ps1` - Fixes the issue when detection exits `1`.

## What To Change First

Open both scripts and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `$ServiceName` | Windows service short name to validate. | Package-specific |
| `$ExpectedState` | Desired service state. | `Running` |
| `$StartService` | Enables starting the service during remediation. | `$true` |
| `$ValidationDelaySeconds` | Wait time before remediation validation. | `5` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Intune Remediations licensing and permissions.
- PowerShell 5.1.
- System context required to start local services.
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

- Detection exits `0` when the configured service is running.
- Detection exits `1` when the service is missing, stopped, or unavailable.
- Remediation starts the service and validates the final state.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Cryptographic-Service-Running`.
- Confirm the setting is available on the target Windows version.
- Confirm another Intune policy, security baseline, GPO, or third-party agent is not changing the state back.
- Review Intune Management Extension logs in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.

## Source Inspiration

Original implementation for this repository. Topic inspiration comes from public Intune and remediation libraries including [JayRHa/EndpointAnalyticsRemediationScripts](https://github.com/JayRHa/EndpointAnalyticsRemediationScripts), [MSEndpointMgr/ProactiveRemediations](https://github.com/MSEndpointMgr/ProactiveRemediations), [microsoft/intune-tenant-doc](https://github.com/microsoft/intune-tenant-doc), [MicrosoftDocs/memdocs](https://github.com/MicrosoftDocs/memdocs), and Microsoft Intune Remediations documentation.

## Pilot Validation

1. Deploy with `$StartService = $false`; a stopped service must remain unchanged and remediation must exit `1`.
2. Test the stopped-service path only on an affected lab device or disposable VM snapshot.
3. Set `$StartService = $true`, verify remediation reads back `Running`, and confirm certificate-chain validation and Windows Update scanning still work.
4. Rerun detection and verify exit `0`; review both package and Intune Management Extension logs.

Microsoft references:

- [Microsoft system-service guidance: Cryptographic Services](https://learn.microsoft.com/en-us/windows-server/security/windows-services/security-guidelines-for-disabling-system-services-in-windows-server#cryptographic-services)
- [Intune Remediations](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)

