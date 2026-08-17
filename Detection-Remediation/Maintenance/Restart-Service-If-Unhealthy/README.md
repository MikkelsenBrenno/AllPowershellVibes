# Restart Service If Unhealthy

## Summary

This remediation package starts a stopped service and can optionally restart it even when it is already running.

## Files

- `Detect.ps1` - Checks service status.
- `Remediate.ps1` - Starts or restarts the service and validates it.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ServiceName` | Service name, not display name. | `Spooler` |
| `$RequiredStatus` | Required detection status. | `Running` |
| `$RestartEvenIfRunning` | Restart even if already running. | `$false` |
| `$ValidationDelaySeconds` | Wait before validation. | `5` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended for service control.

## Customization

Use the service name from `Get-Service`, not the display name.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | No unless your scenario requires it |

## Intune Deployment

Deploy to a pilot group and confirm the service can be safely restarted.

## Exit Codes

- Detection `0` - Service is running.
- Detection `1` - Service is missing or not running.
- Remediation `0` - Service is running after remediation.
- Remediation `1` - Service could not be started or restarted.

## Expected Results

The configured service is running after remediation.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Restart-Service-If-Unhealthy`.
- Confirm the service is not disabled.
- Confirm dependencies are running.

## Common Failures

- The display name was used instead of the service name.
- The service depends on another failed service.
- Restarting a business-critical service disrupts users.
