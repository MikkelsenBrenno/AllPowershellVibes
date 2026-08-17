# Ensure Windows Update Service Enabled

## Summary

This remediation package detects whether the Windows Update service is disabled and can set it back to a configurable startup type.

## Files

- `Detect.ps1` - Checks Windows Update service startup and optional running state.
- `Remediate.ps1` - Sets startup type and optionally starts the service.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ServiceName` | Windows Update service name. | `wuauserv` |
| `$RequireRunning` | Require the service to be running during detection. | `$false` |
| `$StartupType` | Startup type set during remediation. | `Manual` |
| `$StartServiceAfterChange` | Start the service after changing startup type. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

Set `$StartServiceAfterChange` to `$true` only if your update policy expects the service to run immediately.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices where Windows Update service tampering or drift should be corrected.

## Exit Codes

- Detection `0` - Service is compliant.
- Detection `1` - Service is disabled, stopped when required, or missing.
- Remediation `0` - Service startup type is no longer disabled.
- Remediation `1` - Service remains noncompliant.

## Expected Results

The Windows Update service is not disabled.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Windows-Update-Service-Enabled`.
- Confirm another hardening policy is not disabling Windows Update.

## Common Failures

- Security software or policy disables the service again.
- The service is disabled by an upstream configuration profile.
