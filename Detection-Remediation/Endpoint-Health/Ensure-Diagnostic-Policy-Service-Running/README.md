# Ensure Diagnostic Policy Service Running

## Summary

Detects and remediates devices where the Diagnostic Policy Service is stopped, reducing troubleshooting signal for network and Windows diagnostics.

**Repository status:** `PilotReady`. The package passed repository contract review and is ready for a controlled nonproduction pilot. It is not yet `Validated` for broad deployment.

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
- Remediation starts the service and exits `0` only after the final state is `Running`.
- If `$StartService` is `$false`, remediation makes no change and exits `1`; report-only mode never reports a false success.

## Pilot Validation

Use a disposable or nonproduction Windows client and test in the same System/64-bit context configured in Intune.

1. Record the device OS build and the original `DPS` startup mode and state.
2. Run `Detect.ps1` while `DPS` is running; expect exit `0`.
3. Stop `DPS` only on the pilot device. Confirm the temporary loss of Windows diagnostic functionality is acceptable.
4. Run `Detect.ps1`; expect exit `1` and a clear noncompliant message.
5. Run `Remediate.ps1`; expect exit `0` only after `DPS` is running.
6. Run `Detect.ps1` again; expect exit `0`.
7. Review both package logs and the Intune Management Extension log, then restore the original service configuration if the test changed it.

Do not change this package to `Validated` until the result is documented using the evidence fields in `docs/Trusted-Remediation-Pilot.md`.

## Rollback

The package changes only the current service state. To roll back a pilot, restore the recorded original `DPS` state. If you customized the package to change any additional service configuration, restore those recorded values as well.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Diagnostic-Policy-Service-Running`.
- Confirm the setting is available on the target Windows version.
- Confirm another Intune policy, security baseline, GPO, or third-party agent is not changing the state back.
- Review Intune Management Extension logs in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.

## Microsoft References

- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
- [Security guidelines for system services in Windows](https://learn.microsoft.com/en-us/windows-server/security/windows-services/security-guidelines-for-disabling-system-services-in-windows-server) documents service name `DPS`, its diagnostic role, and its default Automatic startup type.

## Source Inspiration

Original implementation for this repository. Topic inspiration comes from public Intune and remediation libraries including [JayRHa/EndpointAnalyticsRemediationScripts](https://github.com/JayRHa/EndpointAnalyticsRemediationScripts), [MSEndpointMgr/ProactiveRemediations](https://github.com/MSEndpointMgr/ProactiveRemediations), [microsoft/intune-tenant-doc](https://github.com/microsoft/intune-tenant-doc), [MicrosoftDocs/memdocs](https://github.com/MicrosoftDocs/memdocs), and Microsoft Intune Remediations documentation.

