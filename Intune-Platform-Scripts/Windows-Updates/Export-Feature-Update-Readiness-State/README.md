# Export Feature Update Readiness State

## Summary

Exports local Windows feature update readiness signals including OS build, free space, TPM, Secure Boot, Windows Update policy, and pending reboot indicators.

## Prerequisites

Run as system with 64-bit PowerShell. Some hardware signals may be unavailable on virtual machines or older devices.

## Customization

Edit the CONFIGURATION section in `Export-Feature-Update-Readiness-State.ps1`.

- `$OutputRoot`: Folder where JSON output is written.
- `$OutputFileName`: Output file name.
- `$WindowsUpdatePolicyPath`: Registry path for Windows Update policy.
- `$PendingRebootPaths`: Registry paths treated as pending reboot signals.

## Intune Settings

Upload `Export-Feature-Update-Readiness-State.ps1` as an Intune platform script. Run as system with 64-bit PowerShell.

## Expected Results

The script writes `FeatureUpdateReadinessState.json` and exits 0 when export succeeds.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-Feature-Update-Readiness-State`. If update readiness looks wrong, compare the JSON with Intune Windows Update rings and feature update assignments.
