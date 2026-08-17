# Check Windows Firewall Profiles

## Summary

This custom compliance package checks whether required Windows Firewall profiles are enabled.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$RequiredProfiles` | Firewall profiles that must be enabled. | Domain, Private, Public |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Firewall cmdlets available.

## Customization

Remove profiles from `$RequiredProfiles` only if your security baseline intentionally excludes them.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to Windows devices where firewall state should be compliance-visible.

## Expected Results

Compliant devices return `FirewallProfilesEnabled` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Windows-Firewall-Profiles`.
- Run `Get-NetFirewallProfile` locally.

## Common Failures

- A local admin or third-party security tool disables a firewall profile.
- Another policy manages firewall profile state.
