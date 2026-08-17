# Remove BuiltIn Appx Packages Template

## Summary

Detects and optionally removes configured built-in AppX packages from installed and provisioned package locations. This gives technicians a safer starting point for AppX cleanup because removal is report-only by default.

## Prerequisites

Run in the system context with 64-bit PowerShell. Confirm each AppX package name and business impact before enabling remediation.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$AppxPackageNamePatterns`: AppX package names or wildcard patterns.
- `$CheckInstalledPackages` and `$RemoveInstalledPackages`: Current installed packages.
- `$CheckProvisionedPackages` and `$RemoveProvisionedPackages`: Provisioned packages for future users.
- `$ApplyAppxRemoval`: Set to `$true` after pilot testing.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Run as system with 64-bit PowerShell.

## Expected Results

Detection exits 1 when configured AppX packages are found. Remediation reports matched package names until `$ApplyAppxRemoval` is enabled.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Remove-BuiltIn-Appx-Packages-Template`. If packages return after removal, verify whether they are provisioned, installed per user, or reintroduced by OS updates.

## Credits

Inspired by public Intune remediation AppX cleanup patterns. See `docs/Open-Source-Inspiration-And-Credits.md`.
