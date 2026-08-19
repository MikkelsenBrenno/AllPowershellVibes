# Ensure SMBv1 Server Protocol Disabled

## Summary

Detects and remediates the documented Lanman Server registry setting that disables SMBv1 server protocol support.

**Repository status:** `PilotReady`. Microsoft documentation supports the shipped registry contract, and both scripts enforce exact registry type and data. This is ready for a controlled tenant pilot, not pre-labeled as `Validated`.

## Copy To Intune

Copy `Detect.ps1` into the **Detection script** field and `Remediate.ps1` into the **Remediation script** field of the same Intune Remediations package. Do not combine the files and do not reverse their roles.

## Configuration Contract

Keep `$RegistryValues` identical in both scripts.

| Path | Name | Type | Required data |
| --- | --- | --- | --- |
| `HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters` | `SMB1` | `DWord` | `0` |

**Effect:** Stops the Windows SMB server from accepting SMBv1 protocol connections after restart.

## Customization

The shipped registry contract is the source-verified baseline for this package name. Keep `$RegistryValues` identical in both scripts. If a different state is required, create a separately named and reviewed package so its purpose, documentation, and rollback remain honest.

## Prerequisites

- Inventory legacy clients, scanners, appliances, and applications that require SMBv1.
- A restart is required for this server protocol setting to take effect.
- This package does not uninstall the SMB1 optional feature or change the SMB client feature state.
- Use Windows PowerShell 5.1 in 64-bit `System` context.
- Do not simultaneously manage these values to a different state through Settings Catalog, Administrative Templates, Endpoint security, security baselines, Group Policy, or another tool.

## Intune Settings

| Setting | Required/recommended value |
| --- | --- |
| Workload | Remediations |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run using logged-on credentials | No |
| Enforce script signature check | Follow tenant signing policy |
| Run script in 64-bit PowerShell | Yes |

Assign to a small, representative nonproduction group first. Intune runs remediation only when detection exits `1`.

## Expected Results

- Detection is read-only and exits `0` only when every value exists with the exact required registry type and data.
- A missing key, missing value, wrong type, wrong data, or read error exits `1`.
- Remediation creates missing keys, writes the reviewed values, reads them back, and exits `0` only after exact final validation.
- Logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-SMBv1-Server-Disabled`.

## Pilot Validation

Use a disposable or nonproduction Windows client in the exact Intune context above.

1. Confirm the device satisfies the documented OS, edition, role, and product prerequisites and record its build.
2. Export or record the original key/value state, including value type and data.
3. Test a missing value; detection must exit `1`.
4. Test the value with the wrong registry type; detection must exit `1`.
5. Test the correct type with wrong data; detection must exit `1`.
6. Set the exact configuration contract; detection must exit `0`.
7. From a restored noncompliant state, let Intune run remediation. It must report success only after the final type and data match.
8. Run detection again, review both package logs and the Intune Management Extension logs, then perform the product check: Restart the pilot device, verify modern SMB clients still connect, and confirm a controlled SMBv1-only client cannot connect.
9. Check required applications, authentication, networking, security telemetry, policy conflict, and reversion after device sync and restart where applicable.
10. Restore the recorded original state if the pilot is not approved.

Do not change this package to `Validated` until non-sensitive pilot evidence is recorded using `docs/Trusted-Remediation-Pilot.md`.

## Rollback

Restore every recorded original value with its original type and data. If a value did not exist before the pilot, remove that value only. Remove a key only when the pilot created it and it has no sibling values. Re-enabling SMBv1 materially weakens file-sharing security and requires a time-limited migration exception.

## Troubleshooting

- Confirm Intune used `System` context and 64-bit PowerShell.
- Compare the effective registry type as well as data; a string such as `"0"` is not a DWORD `0`.
- Check Settings Catalog, Administrative Templates, Endpoint security, security baselines, Group Policy, and third-party agents for duplicate ownership.
- Review `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` and the package log path above.
- Recheck the linked Microsoft applicability and behavior documentation if the value is exact but product behavior does not change.

## Microsoft References

- [Detect, enable, and disable SMBv1, SMBv2, and SMBv3](https://learn.microsoft.com/en-us/windows-server/storage/file-server/troubleshoot/detect-enable-and-disable-smbv1-v2-v3)
- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
