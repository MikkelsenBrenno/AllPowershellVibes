# Ensure Fast Startup Disabled

## Summary

Detects whether Windows Fast Startup is disabled and can apply the `HiberbootEnabled` registry value. This is useful when support teams see update, driver, VPN, or hardware issues that only clear after a true restart.

## Prerequisites

Run in the system context with 64-bit PowerShell. Pilot before enabling remediation because power behavior can vary between device models.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$PowerRegistryPath`: Registry path for Fast Startup.
- `$HiberbootValueName`: Registry value to check.
- `$ExpectedHiberbootValue` or `$TargetHiberbootValue`: Desired value, normally `0`.
- `$ApplyRegistryChange`: Set to `$true` after pilot testing.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Run as system with 64-bit PowerShell.

## Expected Results

Detection exits 0 when Fast Startup is disabled. Remediation reports the intended change until `$ApplyRegistryChange` is enabled.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Fast-Startup-Disabled`. If users still see hybrid shutdown behavior, verify hibernation and local power policy settings.
