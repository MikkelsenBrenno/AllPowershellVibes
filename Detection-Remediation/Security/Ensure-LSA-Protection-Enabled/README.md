# Ensure LSA Protection Enabled

## Summary

Detects whether Local Security Authority protection is enabled and can apply the `RunAsPPL` registry value. The remediation is report-only by default because changes normally require a restart and should be tested against security tooling.

## Prerequisites

Run in the system context with 64-bit PowerShell. Pilot with your endpoint security and identity tools before enabling remediation.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$LsaRegistryPath`: Registry path for LSA settings.
- `$RunAsPplValueName`: Registry value to check.
- `$TargetRunAsPplValue`: Desired DWORD value.
- `$ApplyRegistryChange`: Set to `$true` after pilot testing.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Run as system with 64-bit PowerShell.

## Expected Results

Detection exits 0 when `RunAsPPL` meets or exceeds the configured minimum. Remediation reports the intended registry change until `$ApplyRegistryChange` is enabled.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-LSA-Protection-Enabled`. If LSA protection is still not active after remediation, restart the device and review CodeIntegrity and LSA-related events.
