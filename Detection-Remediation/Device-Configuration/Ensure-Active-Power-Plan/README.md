# Ensure Active Power Plan

## Summary

Detects and optionally sets the active Windows power plan. The remediation starts in report-only mode so administrators can confirm the target power plan GUID before enforcement.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm the target power plan exists on the device model.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$ExpectedPowerPlanGuid`: Power plan GUID detection expects.
- `$TargetPowerPlanGuid`: Power plan GUID remediation activates.
- `$ApplyPowerPlan`: Set to `$true` in `Remediate.ps1` after pilot testing.
- `$ExitZeroInReportingOnlyMode`: Set to `$true` only when report-only remediation should appear successful.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when the active power plan matches.
- Detection exits `1` when the active power plan is missing or different.
- Remediation exits `1` in report-only mode by default.
- Remediation exits `0` after `$ApplyPowerPlan` is enabled and validation succeeds.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Active-Power-Plan`.

## Troubleshooting

- If remediation keeps reporting only, verify `$ApplyPowerPlan` is set to `$true`.
- If validation fails, confirm the target GUID exists on the device.
- If values revert, check OEM tools, GPO, Settings Catalog, or power policy assignments.
- Review script logs and Intune Management Extension logs together.
