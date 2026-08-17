# Ensure Event Log Maximum Size

## Summary

Detects and remediates Windows event logs that are smaller than the configured maximum size. This helps technicians keep enough Application and System history for troubleshooting after incidents.

## Prerequisites

Run in the system context. Confirm target log names and sizes with your operations team before deployment, especially if you collect event logs centrally.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$TargetLogs`: Event logs to check.
- `$MinimumMaximumSizeBytes`: Minimum configured maximum size.
- `$WevtutilPath`: Path to `wevtutil.exe`.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Use 64-bit PowerShell and run as system.

## Expected Results

Detection exits 0 when all configured logs meet the target size. Remediation increases any smaller logs to the configured size.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Event-Log-Maximum-Size`. If a log cannot be updated, confirm the log name with `Get-WinEvent -ListLog *`.
