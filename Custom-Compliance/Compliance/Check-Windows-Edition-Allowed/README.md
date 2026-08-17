# Check Windows Edition Allowed

## Summary

Checks whether a device is running an approved Windows edition. This helps technicians flag devices that are accidentally deployed with Pro, Enterprise, Education, or another edition outside the expected standard.

## Prerequisites

Run in the system context with 64-bit PowerShell. Confirm your accepted Windows edition IDs and product name patterns before assigning the rule broadly.

## Customization

Edit the CONFIGURATION section in `Discover.ps1`.

- `$AllowedEditionIds`: Approved registry `EditionID` values.
- `$CurrentVersionRegistryPath`: Registry path used for Windows version details.

## Intune Settings

Upload `Discover.ps1` as the discovery script and `ComplianceRules.json` as the custom compliance rule file. Run the script as system with 64-bit PowerShell.

## Expected Results

The discovery script returns compressed JSON with `WindowsEditionAllowed`, `ProductName`, `EditionId`, and `AllowedEditionIds`.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Windows-Edition-Allowed`. If a device is unexpectedly noncompliant, compare the returned `EditionId` with the values in the CONFIGURATION section.
