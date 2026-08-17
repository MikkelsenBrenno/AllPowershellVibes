# Detect Local User Account State

## Summary

This remediation package detects whether a local user account exists and whether it is enabled or disabled. Remediation can optionally disable the account.

## Files

- `Detect.ps1` - Checks the account state.
- `Remediate.ps1` - Reports or disables the account when enabled.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$LocalUserName` | Local account name. | `ExampleLocalUser` |
| `$ShouldExist` | Whether the account should exist. | `$false` |
| `$ExpectedEnabledState` | Expected enabled state when it should exist. | `$false` |
| `$DisableAccountIfPresent` | Disable the account during remediation. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- 64-bit PowerShell recommended for LocalAccounts cmdlets.
- System context recommended.

## Customization

Pilot in reporting-only mode before disabling accounts.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to a pilot group and confirm the account name is correct.

## Exit Codes

- Detection `0` - Account state is compliant.
- Detection `1` - Account state is noncompliant.
- Remediation `0` - Account is absent or disabled when enabled.
- Remediation `1` - Account remains noncompliant.

## Expected Results

The configured local account follows the desired existence and enabled-state policy.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Detect-Local-User-Account-State`.
- Confirm the account name is local, not domain-based.

## Common Failures

- LocalAccounts cmdlets are unavailable in 32-bit PowerShell.
- The account name is mistyped.
