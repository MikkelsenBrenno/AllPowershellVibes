# Ensure .NET Framework Strong Crypto And System TLS Defaults

## Summary

Detects and remediates .NET Framework 2.x and 4.x, 32-bit and 64-bit settings to use strong cryptography and operating-system TLS defaults.

**Repository status:** `PilotReady`. Microsoft documentation supports the shipped registry contract, and both scripts enforce exact registry type and data. This is ready for a controlled tenant pilot, not pre-labeled as `Validated`.

## Copy To Intune

Copy `Detect.ps1` into the **Detection script** field and `Remediate.ps1` into the **Remediation script** field of the same Intune Remediations package. Do not combine the files and do not reverse their roles.

## Configuration Contract

Keep `$RegistryValues` identical in both scripts.

| Path | Name | Type | Required data |
| --- | --- | --- | --- |
| `HKLM:\SOFTWARE\Microsoft\.NETFramework\v2.0.50727` | `SchUseStrongCrypto` | `DWord` | `1` |
| `HKLM:\SOFTWARE\Microsoft\.NETFramework\v2.0.50727` | `SystemDefaultTlsVersions` | `DWord` | `1` |
| `HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v2.0.50727` | `SchUseStrongCrypto` | `DWord` | `1` |
| `HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v2.0.50727` | `SystemDefaultTlsVersions` | `DWord` | `1` |
| `HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319` | `SchUseStrongCrypto` | `DWord` | `1` |
| `HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319` | `SystemDefaultTlsVersions` | `DWord` | `1` |
| `HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319` | `SchUseStrongCrypto` | `DWord` | `1` |
| `HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319` | `SystemDefaultTlsVersions` | `DWord` | `1` |

**Effect:** Configures .NET Framework applications to select strong cryptography and let Windows choose the enabled TLS protocol defaults.

## Customization

The shipped registry contract is the source-verified baseline for this package name. Keep `$RegistryValues` identical in both scripts. If a different state is required, create a separately named and reviewed package so its purpose, documentation, and rollback remain honest.

## Prerequisites

- Inventory legacy .NET Framework applications and endpoints that require deprecated TLS protocols or cipher behavior.
- Test both 32-bit and 64-bit applications. The package does not force only TLS 1.2 and does not edit SCHANNEL protocol keys.
- Application or service restart is normally required before an existing process uses the new defaults.
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
- Logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-NETFramework-Strong-Crypto-System-Defaults`.

## Pilot Validation

Use a disposable or nonproduction Windows client in the exact Intune context above.

1. Confirm the device satisfies the documented OS, edition, role, and product prerequisites and record its build.
2. Export or record the original key/value state, including value type and data.
3. Test a missing value; detection must exit `1`.
4. Test the value with the wrong registry type; detection must exit `1`.
5. Test the correct type with wrong data; detection must exit `1`.
6. Set the exact configuration contract; detection must exit `0`.
7. From a restored noncompliant state, let Intune run remediation. It must report success only after the final type and data match.
8. Run detection again, review both package logs and the Intune Management Extension logs, then perform the product check: Restart representative .NET applications and services, test their required endpoints, and confirm negotiated protocols meet the operating-system security policy.
9. Check required applications, authentication, networking, security telemetry, policy conflict, and reversion after device sync and restart where applicable.
10. Restore the recorded original state if the pilot is not approved.

Do not change this package to `Validated` until non-sensitive pilot evidence is recorded using `docs/Trusted-Remediation-Pilot.md`.

## Rollback

Restore every recorded original value with its original type and data. If a value did not exist before the pilot, remove that value only. Remove a key only when the pilot created it and it has no sibling values. Restore all eight recorded values together; document any application that cannot use system TLS defaults and prioritize modernization.

## Troubleshooting

- Confirm Intune used `System` context and 64-bit PowerShell.
- Compare the effective registry type as well as data; a string such as `"0"` is not a DWORD `0`.
- Check Settings Catalog, Administrative Templates, Endpoint security, security baselines, Group Policy, and third-party agents for duplicate ownership.
- Review `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` and the package log path above.
- Recheck the linked Microsoft applicability and behavior documentation if the value is exact but product behavior does not change.

## Microsoft References

- [.NET Framework TLS best practices](https://learn.microsoft.com/en-us/dotnet/framework/network-programming/tls)
- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
