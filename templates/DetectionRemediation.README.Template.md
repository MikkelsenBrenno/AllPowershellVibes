# <Script Name>

## Summary

Describe what the detection script checks and what the remediation script changes.

## Workload Contract

- `Detect.ps1` must read direct evidence for the state named by this package.
- Detection exit `0` means no repair is required. Exit `1` means Intune should run remediation.
- `Remediate.ps1` must change the same state and verify the final result before exit `0`.
- Do not substitute a repository-created marker for the claimed device state.
- Do not put reboot commands in Remediation scripts.
- Review `docs/Intune-Workload-Contracts.md` before changing this scaffold's `Status` from `Template`.

## Files

- `Detect.ps1` - Checks the current state.
- `Remediate.ps1` - Fixes the issue when detection exits `1`.

## What To Change First

Open both scripts and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `<SettingName>` | `<What admins should change>` | `<Default>` |

Common values to check first:

- File paths and registry paths.
- Service names, scheduled task names, app names, or policy value names.
- Expected compliant values.
- Validation delays.
- Optional Teams alert settings in `Remediate.ps1`.

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Intune Remediations licensing and permissions.
- PowerShell 5.1.
- Required local permissions for the setting being checked.

## Customization

Update the `CONFIGURATION` section in both scripts before deployment. That section should contain every value technicians are expected to change, such as paths, registry keys, service names, expected values, URLs, tenant labels, and validation delays.

Keep custom values near the top of the script so admins can review them quickly without reading the full script body.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | `<Yes or No>` |
| Enforce script signature check | `<Tenant policy>` |
| Run script in 64-bit PowerShell | `<Yes when using native HKLM or System32 paths>` |

## Intune Deployment

1. Go to Intune admin center.
2. Open **Devices > Manage devices > Scripts and remediations**.
3. Create a script package.
4. Upload `Detect.ps1` as the detection script.
5. Upload `Remediate.ps1` as the remediation script.
6. Choose the settings above.
7. Assign to a small pilot group first.

## Exit Codes

- Detection `0` - No issue found. Remediation does not run.
- Detection `1` - Issue found. Remediation should run.
- Remediation `0` - Remediation completed.
- Remediation `1` - Remediation failed or issue remains.

## Expected Results

Describe the compliant state after remediation.

## What Success Looks Like

- Detection exits `0` when the device is already compliant.
- Detection exits `1` when the remediation should run.
- Remediation exits `0` only after validating the final state.
- Logs show start, current state, attempted change, and validation result.
- `tools\Test-IntuneWorkloadContracts.ps1` passes before the package is promoted to `PilotReady`.

## Troubleshooting

- Review script logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\<ScriptPackageName>\Detect.log` and `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\<ScriptPackageName>\Remediate.log`.
- Review Intune Management Extension logs.
- Confirm the script context has permission to read and change the setting.
- Test locally in the same 32-bit or 64-bit PowerShell context selected in Intune.

## Common Failures

- A customized path, registry key, service name, or expected value does not match the target device.
- The script is running as user context but needs system/admin permissions.
- The script is running in 32-bit PowerShell but checks a native 64-bit registry or file system path.
- Another policy controls the same setting and changes it back.

## Optional Teams Failure Alerting

If this remediation uses Teams failure alerting, keep `$EnableTeamsFailureAlert = $false` and `$TeamsWebhookUrl = ''` in the repository copy. Admins can enable alerting and paste their own webhook URL in their deployed/customized copy.
