# Ensure-Storage-Sense-Policy-Enabled

## Summary

Detects and optionally configures machine policy registry values for Storage Sense. This gives technicians a simple, copy-friendly baseline for enabling disk cleanup behavior on Windows devices.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Run in 64-bit PowerShell.
- Test on pilot devices before enabling policy writes.
- Confirm these settings do not conflict with Settings Catalog, GPO, or other device configuration profiles.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$StorageSensePolicyPath`: Registry path for Storage Sense policy values.
- `$EnableValueName`: Registry value used to enable Storage Sense.
- `$ExpectedEnableValue`: Expected detection value.
- `$CadenceValueName`: Registry value used for cleanup cadence.
- `$ExpectedCadenceValue`: Expected detection cadence.
- `$RequireCadenceValue`: Require cadence to match during detection.
- `$ApplyPolicy`: Set to `$true` in `Remediate.ps1` after pilot testing.
- `$ExitZeroInReportingOnlyMode`: Set to `$true` only when report-only remediation should appear successful.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when Storage Sense policy matches expected values.
- Detection exits `1` when policy values are missing or different.
- Remediation exits `1` in report-only mode by default.
- Remediation exits `0` after `$ApplyPolicy` is enabled and registry values are written.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Storage-Sense-Policy-Enabled`.

## Troubleshooting

- If remediation keeps reporting only, verify `$ApplyPolicy` is set to `$true`.
- If values revert, check GPO, Settings Catalog, or security baseline assignment.
- If detection fails on cadence, verify `$RequireCadenceValue` and `$WriteCadenceValue` are aligned.
- Review the script log for the exact registry path and values used.
