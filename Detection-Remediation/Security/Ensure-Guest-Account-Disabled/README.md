# Ensure-Guest-Account-Disabled

## Summary

Detects and optionally disables the built-in local Guest account. The scripts locate the account by SID suffix `-501`, so they work even when the account name is localized or renamed.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm whether any devices have an approved Guest-account exception before enforcement.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$GuestSidSuffix`: SID suffix used to locate the built-in Guest account.
- `$ExpectedGuestEnabledState`: Expected detection state. Default `$false` means disabled.
- `$ApplyPolicy`: Set to `$true` in `Remediate.ps1` after pilot testing.
- `$ExitZeroInReportingOnlyMode`: Set to `$true` only when report-only remediation should appear successful.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when the Guest account is disabled.
- Detection exits `1` when the Guest account is enabled or cannot be validated.
- Remediation exits `1` in report-only mode by default.
- Remediation exits `0` after `$ApplyPolicy` is enabled and the account is disabled.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Guest-Account-Disabled`.

## Troubleshooting

- If the account is not found, verify WMI can read local user accounts on the device.
- If remediation keeps reporting only, verify `$ApplyPolicy` is set to `$true`.
- If the account re-enables, check GPO, Settings Catalog, or security baseline assignments.
- Review script logs and Intune Management Extension logs together.
