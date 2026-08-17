# Ensure Local Firewall Rule

## Summary

This remediation package detects a local Windows Firewall rule and can create or update it after an explicit safety switch is enabled.

## Files

- `Detect.ps1` - Checks the firewall rule.
- `Remediate.ps1` - Reports or creates/updates the rule.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$RuleDisplayName` | Firewall rule display name. | `Contoso Example Inbound HTTPS` |
| `$Direction` | Rule direction. | `Inbound` |
| `$Action` | Rule action. | `Allow` |
| `$Protocol` | Protocol. | `TCP` |
| `$LocalPort` | Local port. | `443` |
| `$Profile` | Firewall profiles. | `Domain,Private` |
| `$CreateOrUpdateRule` | Actually change the firewall rule. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

Confirm the rule direction, port, protocol, and profile before enabling `$CreateOrUpdateRule`.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy in reporting-only mode first, then enable `$CreateOrUpdateRule` after pilot validation.

## Exit Codes

- Detection `0` - Firewall rule matches expected settings.
- Detection `1` - Firewall rule is missing or incorrect.
- Remediation `0` - Rule is present or reporting-only success is enabled.
- Remediation `1` - Rule remains noncompliant.

## Expected Results

The configured firewall rule exists and matches the expected settings.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Local-Firewall-Rule`.
- Confirm the rule display name is unique.
- Confirm another policy is not controlling the same rule.

## Common Failures

- `$CreateOrUpdateRule` is still disabled.
- A firewall policy from another management plane overrides local settings.
