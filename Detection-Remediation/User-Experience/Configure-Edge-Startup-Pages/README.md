# Configure Edge Startup Pages

## Summary

This remediation package detects and can configure Microsoft Edge startup page and homepage policy registry values.

## Files

- `Detect.ps1` - Checks Edge policy registry values.
- `Remediate.ps1` - Reports or writes Edge policy registry values.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$EdgePolicyRoot` | Edge policy registry path. | `HKLM:\SOFTWARE\Policies\Microsoft\Edge` |
| `$StartupUrls` | Startup URLs to open. | `https://intranet.contoso.com` |
| `$HomepageLocation` | Edge home page URL. | `https://intranet.contoso.com` |
| `$ConfigureStartupUrls` | Manage startup URLs. | `$true` |
| `$ConfigureHomepage` | Manage home page location. | `$true` |
| `$ApplyPolicy` | Actually write policy values. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Microsoft Edge installed.
- System context recommended for HKLM policy.

## Customization

Replace the Contoso URL values and pilot in reporting-only mode before enabling `$ApplyPolicy`.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy in reporting-only mode first. Enable `$ApplyPolicy` after confirming the expected URLs.

## Exit Codes

- Detection `0` - Edge policy matches expected values.
- Detection `1` - Edge policy is missing or incorrect.
- Remediation `0` - Policy was written or reporting-only success is enabled.
- Remediation `1` - Policy remains noncompliant.

## Expected Results

Edge opens the configured startup URLs and uses the configured homepage policy after policy refresh.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Configure-Edge-Startup-Pages`.
- Open `edge://policy` to confirm policy is loaded.
- Confirm another Edge policy does not override the same values.

## Common Failures

- `$ApplyPolicy` is still disabled.
- URLs are configured under HKLM while testing in a user-only context.
- Edge has not refreshed policy yet.
