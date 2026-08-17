# Ensure-PowerShellV2-Disabled

## Summary

Detects and optionally disables the PowerShell 2.0 optional features. The remediation starts in report-only mode so administrators can confirm legacy compatibility before changing Windows optional features.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm legacy application compatibility before enforcement.
- Plan for a possible reboot if Windows reports a pending feature state.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$FeatureName`: Feature checked by detection.
- `$FeatureNames`: Optional features disabled by remediation.
- `$ValidationFeatureName`: Feature checked after remediation.
- `$CompliantStates`: Feature states treated as compliant.
- `$ApplyPolicy`: Set to `$true` in `Remediate.ps1` after pilot testing.
- `$ExitZeroInReportingOnlyMode`: Set to `$true` only when report-only remediation should appear successful.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when PowerShell 2.0 is disabled or disable pending.
- Detection exits `1` when the feature is enabled or cannot be validated.
- Remediation exits `1` in report-only mode by default.
- Remediation exits `0` after `$ApplyPolicy` is enabled and the feature is disabled or disable pending.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-PowerShellV2-Disabled`.

## Troubleshooting

- If remediation keeps reporting only, verify `$ApplyPolicy` is set to `$true`.
- If state is `DisablePending`, reboot the device during pilot testing.
- If disabling fails, review CBS/DISM servicing health and Windows optional feature logs.
- If applications break after pilot testing, add an approved exception group before broad deployment.
