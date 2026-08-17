# Ensure Remote Desktop Disabled

## Summary

This remediation package detects whether Remote Desktop is enabled and can disable it after an explicit safety switch is enabled.

## Files

- `Detect.ps1` - Checks Remote Desktop registry state and optional firewall rules.
- `Remediate.ps1` - Reports or disables Remote Desktop.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$TerminalServerRegistryPath` | Remote Desktop registry path. | Terminal Server control path |
| `$DenyConnectionsValueName` | Registry value controlling RDP connections. | `fDenyTSConnections` |
| `$CheckFirewallRules` | Check Remote Desktop firewall rules. | `$false` |
| `$DisableFirewallRules` | Disable Remote Desktop firewall rules during remediation. | `$false` |
| `$ApplyPolicy` | Actually write the registry value. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.
- Remote support process reviewed before enforcement.

## Customization

Enable firewall rule checks only after confirming the display group name matches your OS language and firewall configuration.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy in reporting-only mode first. Enable `$ApplyPolicy` after confirming RDP should be disabled for the target group.

## Exit Codes

- Detection `0` - Remote Desktop appears disabled.
- Detection `1` - Remote Desktop appears enabled or could not be validated.
- Remediation `0` - Remote Desktop was disabled or reporting-only success is enabled.
- Remediation `1` - Remote Desktop remains enabled or remediation is disabled.

## Expected Results

Remote Desktop connections are denied by policy.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Remote-Desktop-Disabled`.
- Confirm another policy is not enabling Remote Desktop.
- Confirm remote support tooling does not require RDP.

## Common Failures

- `$ApplyPolicy` is still disabled.
- A GPO or configuration profile re-enables Remote Desktop.
- Firewall display group checks are localized differently on the device.
