# Check Proxy Configuration

## Summary

This custom compliance package checks configurable user proxy, PAC URL, proxy server, and WinHTTP proxy expectations.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ExpectedUserProxyState` | Expected user proxy toggle: `Enabled`, `Disabled`, or `Any`. | `Any` |
| `$ExpectedProxyServerContains` | Required text in the user proxy server value. Empty skips this check. | Empty |
| `$ExpectedAutoConfigUrlContains` | Required text in the PAC URL. Empty skips this check. | Empty |
| `$CheckWinHttpProxy` | Whether to inspect WinHTTP proxy output. | `$true` |
| `$ExpectedWinHttpProxyContains` | Required text in WinHTTP proxy output. Empty skips this check. | Empty |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Run in the context that owns the user proxy setting when checking HKCU.

## Customization

Set only the expectations you need. Leave contains values empty when a tenant does not standardize that part of proxy configuration.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | Yes when checking HKCU user proxy values |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices where proxy drift causes update, enrollment, or application connectivity issues.

## Expected Results

Compliant devices return `ProxyConfigurationCompliant` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Proxy-Configuration`.
- Confirm whether proxy values are user-based, machine-based, or WinHTTP-based.
- Confirm PAC URL and proxy strings are reachable from the device network.

## Common Failures

- The script runs as System but the expected proxy value is configured per user.
- WinHTTP proxy was never imported from browser settings.
- Security software or GPO overwrites proxy values after Intune policy applies.
