# Ensure-AutoRun-AutoPlay-Disabled

## Summary

Detects and optionally disables AutoRun and AutoPlay by writing machine-level Explorer policy values. The remediation starts in report-only mode so administrators can pilot the change before enforcing it.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm that removable media workflows do not require AutoRun behavior.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$ExplorerPolicyPath`: Registry path for Explorer AutoRun and AutoPlay policies.
- `$ExpectedPolicyValues`: Values detection expects.
- `$PolicyValues`: Values remediation writes.
- `$ApplyPolicy`: Set to `$true` in `Remediate.ps1` after pilot testing.
- `$ExitZeroInReportingOnlyMode`: Set to `$true` only when report-only remediation should appear successful.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when configured policy values match.
- Detection exits `1` when the policy path or values are missing or different.
- Remediation exits `1` in report-only mode by default.
- Remediation exits `0` after `$ApplyPolicy` is enabled and values are written successfully.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-AutoRun-AutoPlay-Disabled`.

## Troubleshooting

- If remediation keeps reporting only, verify `$ApplyPolicy` is set to `$true`.
- If values revert, check GPO, Settings Catalog, security baseline, or third-party hardening assignments.
- If user experience does not change immediately, restart Explorer or sign out and back in.
- Review script logs and Intune Management Extension logs together.
