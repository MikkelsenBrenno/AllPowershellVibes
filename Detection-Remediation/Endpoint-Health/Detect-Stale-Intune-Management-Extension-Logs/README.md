# Detect Stale Intune Management Extension Logs

## Summary

This remediation package detects stale or missing Intune Management Extension logs so technicians can find devices that may have stopped checking in properly.

## Files

- `Detect.ps1` - Checks the newest IME log timestamp.
- `Remediate.ps1` - Reports the issue for investigation.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ImeLogFolder` | Intune Management Extension log folder. | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` |
| `$MaximumNewestLogAgeDays` | Maximum age for newest log. | `3` |
| `$ExitZeroInReportingOnlyMode` | Exit successfully when only reporting. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Intune Management Extension installed.

## Customization

Adjust `$MaximumNewestLogAgeDays` for devices that are expected to be offline for longer periods.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices that should actively process Intune Management Extension workloads.

## Exit Codes

- Detection `0` - Recent IME log activity exists.
- Detection `1` - Logs are stale or missing.
- Remediation `0` - Reporting-only success is enabled.
- Remediation `1` - Issue remains.

## Expected Results

Devices with stale IME logs are visible for follow-up.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Detect-Stale-Intune-Management-Extension-Logs`.
- Review IME service state and enrollment health.

## Common Failures

- The device is offline or not receiving Intune workloads.
- The IME service is missing or stopped.
