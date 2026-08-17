# Ensure Office Block Macros From Internet

## Summary

Detects and remediates Microsoft 365 Apps policy values that block VBA macros from files marked as downloaded from the internet.

## Files

- `Detect.ps1` - Checks the current state.
- `Remediate.ps1` - Fixes or reports the issue when detection exits `1`.

## What To Change First

Open both scripts and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `$OfficePolicyRoot` | Policy root to use. Change to HKLM for device-scope policy testing. | `HKCU:\Software\Policies\Microsoft\Office\16.0` |
| `$OfficeAppNames` | Office apps to configure. | `word`, `excel`, `powerpoint`, `access` |
| `$MacroPolicyValueName` | Office macro policy value name. | `blockcontentexecutionfrominternet` |
| `$DesiredMacroPolicyValue` | Desired policy value. | `1` |
| `$ValidationDelaySeconds` | Wait time before remediation validation. | `2` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft 365 Apps installed or policy-ready.
- PowerShell 5.1.
- Run in the logged-on user context for HKCU policy.
- 64-bit PowerShell recommended.

## Customization

Update the `CONFIGURATION` section in both scripts before deployment. Keep tenant-specific values, paths, profile names, and safety toggles near the top so technicians can review them immediately.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | Yes |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

1. Go to Intune admin center.
2. Open **Devices > Manage devices > Scripts and remediations**.
3. Create a script package.
4. Upload `Detect.ps1` as the detection script.
5. Upload `Remediate.ps1` as the remediation script.
6. Choose the settings above.
7. Assign to a small pilot group first.

## Expected Results

- Detection exits `0` when each configured Office app has the macro policy value.
- Remediation creates missing policy keys and writes the desired value.
- Office apps may need to restart before reading the new policy state.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Office-Block-Macros-From-Internet`.
- Confirm whether the script is running as user context for HKCU or system context for HKLM.
- Check whether Microsoft 365 Apps Administrative Template or Settings Catalog policy already controls the same setting.

## Source Inspiration

Original implementation for this repository. Topic inspiration comes from public Microsoft 365 Apps and Intune hardening patterns in [aaronparker/intune](https://github.com/aaronparker/intune) and Microsoft policy documentation in [MicrosoftDocs/memdocs](https://github.com/MicrosoftDocs/memdocs).

