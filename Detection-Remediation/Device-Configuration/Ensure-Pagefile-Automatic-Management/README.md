# Ensure Pagefile Automatic Management

## Summary

Detects whether Windows automatic pagefile management matches the configured target and can remediate it. The remediation is report-only by default because pagefile changes may require a reboot.

## Prerequisites

Run in the system context with 64-bit PowerShell. Pilot on representative hardware before enabling remediation.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$ExpectedAutomaticManagedPagefile`: Desired automatic pagefile state.
- `$ApplyPagefileChange`: Set to `$true` in `Remediate.ps1` after pilot testing.
- `$RebootMessage`: Message logged when a change is applied.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Use 64-bit PowerShell and run as system.

## Expected Results

Detection exits 0 when automatic pagefile management matches the target. Remediation exits 0 in report-only mode or after applying the configured change.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Pagefile-Automatic-Management`. If settings do not appear to change, restart the device and check `Win32_ComputerSystem.AutomaticManagedPagefile` again.
