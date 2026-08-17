# Ensure Compliance Registry Marker

## Summary

Detects and optionally writes a configurable local registry marker. This is useful when teams need a small remediation package that records a baseline version, migration state, or local completion marker.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context when writing HKLM.
- Run in 64-bit PowerShell when using native HKLM paths.
- Confirm the marker does not overlap with another app or baseline.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$MarkerRegistryPath`: Registry key that stores the marker.
- `$MarkerValueName`: Registry value name to inspect or write.
- `$ExpectedMarkerValue`: Value expected by detection.
- `$MarkerValue`: Value written by remediation.
- `$MarkerPropertyType`: Registry value type written by remediation.
- `$ApplyMarker`: Set to `$true` in `Remediate.ps1` after pilot testing.
- `$ExitZeroInReportingOnlyMode`: Set to `$true` only when report-only remediation should appear successful.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when the marker exists and matches.
- Detection exits `1` when the marker is missing or different.
- Remediation exits `1` in report-only mode by default.
- Remediation exits `0` after `$ApplyMarker` is enabled and validation succeeds.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Compliance-Registry-Marker`.

## Troubleshooting

- If remediation keeps reporting only, verify `$ApplyMarker` is set to `$true`.
- If detection fails after remediation, confirm detection and remediation values match.
- If values appear under `WOW6432Node`, confirm Intune runs the script in 64-bit PowerShell.
- Review script logs and Intune Management Extension logs together.
