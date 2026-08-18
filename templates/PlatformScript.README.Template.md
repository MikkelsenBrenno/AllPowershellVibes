# <Platform Script Name>

## Summary

Describe what the script configures on Windows devices.

## Workload Contract

- This is one standalone action, not a detection/remediation pair and not a compliance discovery script.
- The script should validate its result before exit `0` when practical.
- A successful Platform script normally does not run again unless its script or policy changes; failures are retried during the next three consecutive Intune Management Extension check-ins.
- Use Remediations instead when recurring drift evaluation is required.
- Do not describe a local report as centralized reporting unless a documented process collects it.
- Review `docs/Intune-Workload-Contracts.md` before changing this scaffold's `Status` from `Template`.

## File

- `<ScriptName>.ps1`

## What To Change First

Open the script and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `<SettingName>` | `<What admins should change>` | `<Default>` |

Common values to check first:

- File paths and registry paths.
- Service names, scheduled task names, app names, URLs, or policy value names.
- Expected final values.
- Validation delays.
- Optional Teams alert settings when alerting is included.

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Intune Management Extension installed.
- PowerShell 5.1.
- Required local permissions for the setting being changed.

## Customization

Update the `CONFIGURATION` section in the script before deployment. That section should contain every value technicians are expected to change, such as paths, registry keys, service names, expected values, URLs, tenant labels, and validation delays.

Keep custom values near the top of the script so admins can review them quickly without reading the full script body.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `<ScriptName>.ps1` |
| Run this script using the logged-on credentials | `<Yes or No>` |
| Enforce script signature check | `<Tenant policy>` |
| Run script in 64-bit PowerShell | `<Yes when using native HKLM or System32 paths>` |

## Intune Deployment

1. Go to Intune admin center.
2. Open **Devices > Manage devices > Scripts and remediations > Platform scripts**.
3. Add a Windows 10 and later PowerShell script.
4. Upload the script.
5. Choose the settings above.
6. Assign to a pilot group.

## Exit Codes

- `0` - Script completed successfully.
- `1` - Script failed.

## Expected Results

Describe what should change on the device.

## What Success Looks Like

- The script exits `0`.
- Logs show start, current state, attempted change, and validation result.
- The configured state remains after policy refresh or restart when applicable.
- `tools\Test-IntuneWorkloadContracts.ps1` passes before the package is promoted to `PilotReady`.

## Troubleshooting

- Review script logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\<ScriptPackageName>\<ScriptName>.log`.
- Review Intune Management Extension logs.
- Confirm the script was changed or reassigned if you need it to run again.
- Confirm system time is accurate on the device.

## Common Failures

- A customized path, registry key, service name, URL, or expected value does not match the target device.
- The script is running in user context but needs system/admin permissions.
- The script is running in 32-bit PowerShell but checks a native 64-bit registry or file system path.
- The script already ran once and needs a content change or reassignment before Intune runs it again.
