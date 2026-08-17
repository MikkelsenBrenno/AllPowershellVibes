# Check Computer Name Prefix

## Summary

Checks whether the local computer name starts with an approved prefix. This is handy for organizations that use naming conventions to separate laptops, desktops, kiosks, labs, or regions.

## Prerequisites

Run in the system context. Confirm your naming standard before deployment and decide whether prefix matching should be case sensitive.

## Customization

Edit the CONFIGURATION section in `Discover.ps1`.

- `$AllowedComputerNamePrefixes`: Prefixes that should be treated as compliant.
- `$CaseSensitivePrefixMatch`: Set to `$true` only if case must match exactly.

## Intune Settings

Upload `Discover.ps1` as the discovery script and `ComplianceRules.json` as the custom compliance rule file. Use 64-bit PowerShell and run as system.

## Expected Results

The discovery script returns compressed JSON with `ComputerNamePrefixCompliant`, `ComputerName`, and `AllowedPrefixes`.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Computer-Name-Prefix`. If a device is noncompliant, verify the actual device name in Intune and compare it with the configured prefixes.
