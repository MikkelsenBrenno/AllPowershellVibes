# Export MDM Enrollment State

## Summary

Exports local MDM enrollment registry state and enrollment task names for Intune enrollment troubleshooting.

## File

- `Export-MDM-Enrollment-State.ps1`

## What To Change First

Open the script and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `$OutputRoot` | Folder where JSON output is written. | `C:\ProgramData\IntuneScriptLibrary\Inventory` |
| `$OutputFileName` | Output file name. | `MDMEnrollmentState.json` |
| `$EnrollmentRoot` | Enrollment registry root to inspect. | `HKLM:\SOFTWARE\Microsoft\Enrollments` |
| `$EnterpriseMgmtTaskRoot` | Scheduled task path for EnterpriseMgmt tasks. | `\Microsoft\Windows\EnterpriseMgmt` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Intune Management Extension installed.
- PowerShell 5.1.
- System context recommended unless the script explicitly targets HKCU/user profile state.
- 64-bit PowerShell recommended.

## Customization

Update the `CONFIGURATION` section in the script before deployment. Keep paths, registry keys, service names, output file names, URLs, and expected values near the top so technicians can customize quickly.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Export-MDM-Enrollment-State.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

1. Go to Intune admin center.
2. Open **Devices > Manage devices > Scripts and remediations > Platform scripts**.
3. Add a Windows 10 and later PowerShell script.
4. Upload the script.
5. Choose the settings above.
6. Assign to a pilot group.

## Expected Results

- The script exits `0` when the JSON output is written.
- The output file is created under the configured `$OutputRoot`.
- Script logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\<ScriptPackageName>`.

## Troubleshooting

- Review the script log under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\<ScriptPackageName>`.
- Confirm the script context can write to `$OutputRoot`.
- Confirm required local cmdlets, registry paths, services, or event logs exist on the target Windows version.
- Rerun in 64-bit PowerShell if native HKLM or System32 data appears missing.

## Source Inspiration

Original implementation for this repository. Topic inspiration comes from public Intune and remediation libraries including [JayRHa/EndpointAnalyticsRemediationScripts](https://github.com/JayRHa/EndpointAnalyticsRemediationScripts), [microsoft/intune-tenant-doc](https://github.com/microsoft/intune-tenant-doc), [microsoftgraph/powershell-intune-samples](https://github.com/microsoftgraph/powershell-intune-samples), and Microsoft Intune platform script guidance.

