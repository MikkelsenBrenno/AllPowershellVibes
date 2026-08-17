# Ensure NIC Power Saving Disabled

## Summary

Detects physical network adapters that allow Windows to turn off the device for power saving. The remediation is report-only by default so technicians can confirm adapter matching before making changes.

## Prerequisites

Run in the system context on Windows devices with `Get-NetAdapter` and root WMI power management classes available. Pilot carefully on laptop models and docking setups.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$AdapterNamePatterns`: Adapter names to include.
- `$IgnoreDisconnectedAdapters`: Whether disconnected adapters are skipped.
- `$ApplyPowerManagementChange`: Set to `$true` in `Remediate.ps1` after pilot testing.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Use 64-bit PowerShell, run as system, and start with a small pilot group.

## Expected Results

Detection exits 0 when matching adapters do not allow power saving and exits 1 when a matching adapter is still enabled for power saving.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-NIC-Power-Saving-Disabled`. If adapters are not found, adjust `$AdapterNamePatterns` and compare against `Get-NetAdapter -Physical`.
