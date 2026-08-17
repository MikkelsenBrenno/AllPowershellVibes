# Ensure DNS Client Service Running

## Summary

Detects and remediates devices where the DNS Client service is not running, which can break name resolution and Intune connectivity troubleshooting.

## Files

- `Detect.ps1` - Checks the current state.
- `Remediate.ps1` - Fixes or reports the issue when detection exits `1`.

## What To Change First

Open both scripts and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `$ServiceName` | Windows service short name. | Package-specific |
| `$DesiredState` | Desired service state. | `Running` |
| `$ValidationDelaySeconds` | Wait time before remediation validation. | `5` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context.
- Permission to start the configured service.

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

- Detection exits `0` when the configured service is running.
- Remediation starts the service and validates the final service state.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\<ScriptPackageName>`.
- Confirm the service exists on the Windows version being targeted.
- Review system event logs if the service refuses to start.
- Check whether another policy or hardening baseline intentionally disables the service.

## Source Inspiration

Original implementation for this repository. Topic inspiration comes from service self-healing patterns in public Intune remediation examples, including [JayRHa/EndpointAnalyticsRemediationScripts](https://github.com/JayRHa/EndpointAnalyticsRemediationScripts), [MSEndpointMgr/ProactiveRemediations](https://github.com/MSEndpointMgr/ProactiveRemediations), and Microsoft Intune Remediations guidance.

