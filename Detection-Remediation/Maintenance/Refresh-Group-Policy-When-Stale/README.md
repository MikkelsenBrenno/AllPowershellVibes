# Refresh Group Policy When Stale

## Summary

Detects stale machine Group Policy refresh data and runs `gpupdate` when the threshold is exceeded. This follows a common Intune remediation pattern for reducing configuration drift on hybrid devices.

## Prerequisites

Run in the system context with 64-bit PowerShell. This is most useful for hybrid-joined or domain-joined devices that still rely on Group Policy.

## Customization

Edit the CONFIGURATION sections in both scripts.

- `$MaximumRefreshAgeDays`: Number of days before refresh is considered stale.
- `$MachineGroupPolicyStatePath`: Registry path used to read the last machine refresh time.
- `$TargetsToRefresh`: `computer`, `user`, or both.
- `$ForceRefresh`: Adds `/force` to gpupdate.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Run as system with 64-bit PowerShell.

## Expected Results

Detection exits 0 when Group Policy refreshed within the configured window and exits 1 when it is stale. Remediation runs `gpupdate` for the configured targets.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Refresh-Group-Policy-When-Stale`. If the timestamp is missing, verify the device still receives Group Policy and review Event Viewer under GroupPolicy Operational logs.
