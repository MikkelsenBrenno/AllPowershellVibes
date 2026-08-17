# Firewall: Enable All Profiles

## Summary

This remediation package checks whether Windows Firewall is enabled for the configured profiles and enables it when needed.

The default configuration checks the `Domain`, `Private`, and `Public` profiles.

## Files

- `Detect.ps1` - Checks whether selected firewall profiles are enabled.
- `Remediate.ps1` - Enables selected firewall profiles and validates the final state.

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- NetSecurity PowerShell module available.
- System context recommended.
- 64-bit PowerShell recommended.

## Customization

Update the `CONFIGURATION` section in both scripts.

| Setting | Description | Default |
| --- | --- | --- |
| `$FirewallProfiles` | Firewall profiles to check and enable. Use one or more of `Domain`, `Private`, `Public`. | `Domain`, `Private`, `Public` |
| `$ValidationDelaySeconds` | Wait time before remediation validation. | `3` |

## Intune Deployment

1. Go to Intune admin center.
2. Open **Devices > Manage devices > Scripts and remediations**.
3. Create a new script package.
4. Upload `Detect.ps1` as the detection script.
5. Upload `Remediate.ps1` as the remediation script.
6. Run as system.
7. Run in 64-bit PowerShell.
8. Assign to a pilot group before broad deployment.

## Expected Results

- Detection exits `0` when all configured firewall profiles are enabled.
- Detection exits `1` when one or more configured profiles are disabled.
- Remediation exits `0` only after all configured profiles are confirmed enabled.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Firewall-Enable-All-Profiles\Detect.log` and `Remediate.log`.
- Confirm the NetSecurity module is available.
- Check whether another policy, security baseline, or GPO controls Windows Firewall.
- Review Intune Management Extension logs in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
