# Restart Intune Management Extension Service

## Summary

This remediation package detects whether the Intune Management Extension service is running and can start or optionally restart it.

## Files

- `Detect.ps1` - Checks IME service state.
- `Remediate.ps1` - Starts or optionally restarts the service.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ServiceName` | Intune Management Extension service name. | `IntuneManagementExtension` |
| `$RequiredStatus` | Required detection status. | `Running` |
| `$RestartIfAlreadyRunning` | Restart the service even if running. | `$false` |
| `$StartupType` | Startup type set during remediation. | `Automatic` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Intune Management Extension installed.
- System context recommended.

## Customization

Keep `$RestartIfAlreadyRunning` disabled unless you intentionally want to bounce the service during remediation windows.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices where IME service drift should be corrected.

## Exit Codes

- Detection `0` - Service is running.
- Detection `1` - Service is missing or not running.
- Remediation `0` - Service is running after remediation.
- Remediation `1` - Service could not be started.

## Expected Results

The Intune Management Extension service is running and set to the configured startup type.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Restart-Intune-Management-Extension-Service`.
- Review IME logs under `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.

## Common Failures

- Intune Management Extension is not installed.
- Another process repeatedly stops the service.
