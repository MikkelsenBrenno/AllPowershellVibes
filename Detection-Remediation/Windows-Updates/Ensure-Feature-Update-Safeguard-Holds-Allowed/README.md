# Ensure Feature Update Safeguard Holds Allowed

## Summary

Detects whether the Windows Update for Business safeguard hold override is enabled and can set it back to a safer state. This is useful when feature update troubleshooting uncovers devices bypassing safeguard holds.

## Prerequisites

Run in the system context with 64-bit PowerShell. Confirm your Windows Update for Business policy strategy before enabling remediation.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$WindowsUpdatePolicyPath`: Registry path for Windows Update policy.
- `$SafeguardPolicyValueName`: Policy value to inspect.
- `$RemediationAction`: Use `SetZero` or `RemoveValue`.
- `$ApplyPolicyChange`: Set to `$true` after pilot testing.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Run as system with 64-bit PowerShell.

## Expected Results

Detection exits 0 when safeguard holds are allowed and exits 1 when `DisableWUfBSafeguards` is set to `1`. Remediation reports the intended action until `$ApplyPolicyChange` is enabled.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Feature-Update-Safeguard-Holds-Allowed`. If policy keeps returning, review Intune Windows Update rings, Settings Catalog, and any local Group Policy sources.
