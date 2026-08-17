# Ensure Windows Update Policy Keys Present

## Summary

Detects and optionally creates expected Windows Update policy registry values. This is meant as a copy-and-customize baseline for technicians who need visible registry settings near the top of the script.

## Prerequisites

Run in the system context with 64-bit PowerShell. Confirm that the chosen registry policy values do not conflict with Windows Update rings, feature update policies, or other Intune settings.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$ExpectedRegistryValues`: Registry paths, names, types, and values to validate.
- `$ApplyRegistryChanges`: Set to `$true` in `Remediate.ps1` after pilot testing.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Use 64-bit PowerShell and run as system.

## Expected Results

Detection exits 0 when all configured values match and exits 1 when any value is missing or different. Remediation defaults to report-only mode.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Windows-Update-Policy-Keys-Present`. If devices do not follow the expected policy, check Intune policy precedence and local group policy result data.
