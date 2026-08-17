# Local Administrators Audit Unauthorized

## Summary

This remediation package audits the local Administrators group and can optionally remove members that are not in the allowed list.

Removal is disabled by default. Enable removal only after pilot testing.

## Files

- `Detect.ps1` - Checks local group membership.
- `Remediate.ps1` - Reports unauthorized members or removes them when enabled.

## What To Change First

Open both scripts and review the `CONFIGURATION` section.

| Setting | Description | Default |
| --- | --- | --- |
| `$LocalGroupName` | Local group to evaluate. | `Administrators` |
| `$AllowedLocalAdministratorMembers` | Members allowed to remain in the group. | `Administrator` |
| `$CompareAccountNameOnly` | Compare only the account name after the slash. | `$true` |
| `$RemoveUnauthorizedMembers` | Actually remove unauthorized members. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- 64-bit PowerShell recommended for the LocalAccounts cmdlets.
- System context required for local group changes.

## Customization

Start in audit-only mode. Review logs and Intune results before setting `$RemoveUnauthorizedMembers = $true`.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

1. Configure the allowed member list in both scripts.
2. Deploy to a small pilot group with removal disabled.
3. Review logs and device results.
4. Enable removal only after confirming the allowed list is correct.

## Exit Codes

- Detection `0` - No unauthorized members found.
- Detection `1` - Unauthorized members found.
- Remediation `0` - No unauthorized members remain.
- Remediation `1` - Unauthorized members remain or removal is disabled.

## Expected Results

The local Administrators group contains only approved members.

## What Success Looks Like

- Logs list every local group member found.
- Remediation exits `0` only when no unauthorized members remain.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Local-Administrators-Audit-Unauthorized`.
- Confirm the local group name matches the OS language.
- Confirm the allowed member names match how `Get-LocalGroupMember` returns them.

## Common Failures

- The allowed list misses a required break-glass or management account.
- The script runs in 32-bit PowerShell and LocalAccounts cmdlets are unavailable.
- `$CompareAccountNameOnly = $true` allows the same leaf name from multiple domains.
