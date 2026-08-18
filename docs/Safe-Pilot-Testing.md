# Safe Pilot Testing

Every script in this repository should be treated as a starting point. Even read-only scripts can create noisy reporting if the expectation is wrong.

## Before Intune

1. Read the package `README.md`.
2. Review every value in the `CONFIGURATION` section.
3. Search for safety switches such as `$ApplyPolicy` or `$DeleteCacheItems`.
4. Run the script in a lab VM or disposable test device.
5. Confirm logs are created.
6. Confirm exit codes match the README.

## Match The Intune Context

Test in the same context you will deploy:

| Intune setting | Local test idea |
| --- | --- |
| System context | Run elevated or use a system-context test tool. |
| User context | Run as the target user. |
| 64-bit PowerShell | Use `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`. |
| 32-bit PowerShell | Use `%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe`. |

## Pilot Groups

Start with a small group that represents the real fleet:

- One standard user device.
- One admin or technician device.
- One recently built device.
- One older device.
- One device on VPN or remote network.

## Rollback Thinking

Before broad deployment, know the rollback:

- Remediation packages may need a reverse remediation.
- Win32 packages should include `Uninstall.ps1`.
- Registry policy changes may require removing values.
- File deletion scripts should stay report-only until reviewed.
- Certificate and firewall changes should be approved by security owners.

## Evidence To Collect

For each pilot, capture:

- Intune script status.
- Script-specific log file.
- Intune Management Extension log excerpt.
- Before and after state.
- Any user-facing impact.

For Remediation packages, use the detailed technician workflow and non-sensitive evidence record in `docs/Trusted-Remediation-Pilot.md`.
