# Check DNS Suffix Search List

## Summary

Checks whether required DNS suffixes are configured on the device. This helps support teams validate name-resolution configuration for hybrid domains, VPN scenarios, and internal applications.

## Prerequisites

Run in the system context. Confirm the required suffix list with your network team before deploying to production.

## Customization

Edit the CONFIGURATION section in `Discover.ps1`.

- `$RequiredSuffixes`: DNS suffixes that must be present.
- `$TcpipParametersPath`: Registry location to inspect.

## Intune Settings

Upload `Discover.ps1` as the discovery script and `ComplianceRules.json` as the custom compliance rule file. Use 64-bit PowerShell and run the script as system.

## Expected Results

The discovery script returns compressed JSON with `DnsSuffixSearchListCompliant`, `ConfiguredSuffixes`, and `MissingSuffixes`.

## Troubleshooting

Check the local log under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-DNS-Suffix-Search-List`. If devices are unexpectedly noncompliant, compare the registry `SearchList` value with `ipconfig /all`.
