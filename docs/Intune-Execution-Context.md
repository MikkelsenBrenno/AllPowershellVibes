# Intune Execution Context

PowerShell behavior in Intune depends on workload type, execution context, and 32-bit or 64-bit host selection.

## System vs User Context

Use system context for:

- HKLM registry settings.
- Windows services.
- BitLocker state.
- Machine-wide files under `Program Files` or `ProgramData`.
- Time zone and device-level configuration.

Use user context for:

- HKCU registry settings.
- User profile files.
- Per-user application preferences.
- Shortcuts or settings that apply only to the signed-in user.

If a user is not signed in, user-context workloads might not have the profile access your script expects.

## 32-Bit vs 64-Bit PowerShell

On 64-bit Windows, 32-bit PowerShell can see redirected registry and file system paths.

Common examples:

- `HKLM:\SOFTWARE` can be redirected to `HKLM:\SOFTWARE\WOW6432Node`.
- `C:\Windows\System32` can be redirected for 32-bit processes.

Choose 64-bit PowerShell when a script works with native machine settings, 64-bit applications, HKLM software keys, or system paths.

For Win32 app command lines, use this PowerShell path when you need to force 64-bit Windows PowerShell from the Intune Management Extension:

```text
%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe
```

## Exit Codes by Workload

| Workload | Exit 0 | Exit 1 |
| --- | --- | --- |
| Remediation detection | No issue detected | Issue detected, run remediation |
| Remediation script | Remediation succeeded | Remediation failed |
| Platform script | Script succeeded | Script failed |
| Win32 install | Install succeeded | Install failed |
| Win32 uninstall | Uninstall succeeded | Uninstall failed |
| Win32 detection | Detected when STDOUT is also written | Not detected |

Custom compliance discovery scripts should return compressed JSON. Avoid using ordinary progress output because Intune evaluates STDOUT as JSON.

## Detection and Remediation Logic

Detection scripts should be read-only whenever possible.

Recommended pattern:

1. Detect current state.
2. If compliant, write a short message and exit `0`.
3. If noncompliant, write a short message and exit `1`.
4. Let the remediation script make changes.

Remediation scripts should:

- Make only the needed change.
- Validate the change.
- Exit `0` only after validation succeeds.
- Exit `1` when the issue remains.

## Platform Script Behavior

Platform scripts run through the Intune Management Extension. After assignment, a script reports results after it runs. It generally does not run again unless the script or policy changes. If a script fails, the Intune Management Extension can retry on subsequent check-ins.

## Custom Compliance Behavior

Windows custom compliance uses:

- A discovery PowerShell script.
- A JSON rules file.

The discovery script returns setting names and values. The JSON rules file defines compliant values. `SettingName` values are case-sensitive and must match the script output.

Example discovery output:

```json
{"BitLockerProtected":true,"BitLockerEncryptionPercentage":100}
```

## Useful Log Locations

- Script-specific logs: `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\<ScriptPackageName>\<ScriptName>.log`
- Intune Management Extension logs: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`

Always test scripts in the same context and architecture you choose in Intune.
