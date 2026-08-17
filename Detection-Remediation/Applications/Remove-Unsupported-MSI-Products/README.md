# Remove Unsupported MSI Products

## Summary

Detects unsupported MSI applications by product code or display name pattern and can uninstall explicit product codes. This turns the common "unsupported apps" remediation idea into a safer copy-and-customize package.

## Prerequisites

Run in the system context with 64-bit PowerShell. Replace the placeholder product code before assigning to production.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$UnsupportedProductCodes`: MSI product codes to detect and uninstall.
- `$UnsupportedDisplayNamePatterns`: Display name patterns used for detection.
- `$ApplyUninstall`: Set to `$true` in `Remediate.ps1` after pilot testing.
- `$MsiExecExtraArguments`: Silent uninstall switches.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Run as system with 64-bit PowerShell.

## Expected Results

Detection exits 1 when unsupported products are found. Remediation reports intended uninstall commands until `$ApplyUninstall` is enabled.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Remove-Unsupported-MSI-Products`. If uninstall fails, verify the product code and test the msiexec command manually on a pilot device.
