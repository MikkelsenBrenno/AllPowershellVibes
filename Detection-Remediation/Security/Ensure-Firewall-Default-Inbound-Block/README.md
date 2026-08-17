# Ensure-Firewall-Default-Inbound-Block

## Summary

Detects and optionally sets the Windows Firewall default inbound action to `Block` for selected profiles. This is useful when teams want a remediation package that catches local drift from a firewall baseline.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm that allowed inbound access is handled through explicit firewall rules.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$FirewallProfiles`: Profiles to inspect or configure. Choose from `Domain`, `Private`, and `Public`.
- `$ExpectedDefaultInboundAction`: Expected firewall default inbound action. Default is `Block`.
- `$ApplyPolicy`: Set to `$true` in `Remediate.ps1` after pilot testing.
- `$ExitZeroInReportingOnlyMode`: Set to `$true` only when report-only remediation should appear successful.
- `$ValidationDelaySeconds`: Delay before post-remediation validation.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when selected profiles use the expected inbound action.
- Detection exits `1` when one or more profiles use a different inbound action.
- Remediation exits `1` in report-only mode by default.
- Remediation exits `0` after `$ApplyPolicy` is enabled and validation succeeds.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Firewall-Default-Inbound-Block`.

## Troubleshooting

- If remediation keeps reporting only, verify `$ApplyPolicy` is set to `$true`.
- If values revert, check GPO, firewall profile policy, Settings Catalog, security baseline, or Defender Firewall CSP assignments.
- If line-of-business apps break after enforcement, add explicit allow rules instead of changing default inbound behavior.
- Review script logs and Intune Management Extension logs together.
