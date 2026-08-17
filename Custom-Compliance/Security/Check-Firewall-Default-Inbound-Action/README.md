# Check-Firewall-Default-Inbound-Action

## Summary

Reports whether selected Windows Firewall profiles block inbound traffic by default. The output includes each profile, its enabled state, and the detected default inbound action.

## Prerequisites

- Deploy as an Intune custom compliance discovery script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm any firewall baseline exceptions before enforcing.

## Customization

Edit the CONFIGURATION section near the top of `Discover.ps1`:

- `$FirewallProfiles`: Firewall profiles to evaluate.
- `$ExpectedDefaultInboundAction`: Expected inbound action. Default is `Block`.

## Intune Settings

- Discovery script: `Discover.ps1`
- Rules file: `ComplianceRules.json`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Output is compressed JSON.
- `FirewallDefaultInboundCompliant` is `true` when all selected profiles match policy.
- `Profiles` lists each selected profile and its raw firewall values.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Firewall-Default-Inbound-Action`.

## Troubleshooting

- If a profile is noncompliant, review profile-specific firewall policy assignments.
- If values revert, check GPO, Settings Catalog, or security baseline assignment.
- If the firewall cmdlets are missing, confirm the target OS supports the NetSecurity module.
- Use the matching remediation package only after pilot testing.
