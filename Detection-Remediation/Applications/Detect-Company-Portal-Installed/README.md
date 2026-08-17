# Detect Company Portal Installed

## Summary

This remediation package detects whether Company Portal is installed or provisioned. Remediation is reporting-only and points admins back to an Intune app deployment.

## Files

- `Detect.ps1` - Checks installed and provisioned AppX packages.
- `Remediate.ps1` - Reports that Company Portal should be deployed from Intune.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$AppxPackageName` | AppX package name to detect. | `Microsoft.CompanyPortal` |
| `$CheckProvisionedPackage` | Also check provisioned AppX packages. | `$true` |
| `$ExitZeroInReportingOnlyMode` | Exit successfully when only reporting. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.
- Company Portal deployed separately as an Intune app.

## Customization

Use this as a reporting companion to your Company Portal app assignment. Keep remediation reporting-only unless you replace it with an approved install method.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices that should have Company Portal available.

## Exit Codes

- Detection `0` - Company Portal is installed or provisioned.
- Detection `1` - Company Portal is missing.
- Remediation `0` - Reporting-only success is enabled.
- Remediation `1` - Company Portal remains missing.

## Expected Results

Devices missing Company Portal are visible in remediation reporting.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Detect-Company-Portal-Installed`.
- Confirm the Microsoft Store app assignment is targeted to the same devices.

## Common Failures

- The device is not targeted by the Company Portal app assignment.
- Store app installation is blocked by policy or network controls.
