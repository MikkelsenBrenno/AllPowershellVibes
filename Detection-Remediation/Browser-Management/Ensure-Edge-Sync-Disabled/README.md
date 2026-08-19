# Ensure Edge Sync Disabled

## Summary

Disables Microsoft Edge profile-data synchronization.

**Repository status:** `PilotReady`. Microsoft documents the path, value name, type, and data semantics, and both scripts enforce exact registry type and data. This is ready for a controlled tenant pilot, not pre-labeled as `Validated`.

## Copy To Intune

Copy `Detect.ps1` into the **Detection script** field and `Remediate.ps1` into the **Remediation script** field of the same Intune Remediations package. Do not combine the files and do not reverse their roles.

## Configuration Contract

Keep `$RegistryValues` identical in both scripts.

| Path | Name | Type | Required data |
| --- | --- | --- | --- |
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `SyncDisabled` | `DWord` | `1` |

**Effect:** Applies the Edge policy that disables synchronization of browser data across signed-in profiles.

Detection proves only that the documented registry policy contract is exact. Product behavior must be confirmed by the pilot check below.

## Customization

The shipped registry contract is the source-verified baseline for this package name. Keep `$RegistryValues` identical in both scripts. If a different state is required, create a separately named and reviewed package so its purpose, documentation, and rollback remain honest.

## Prerequisites

- Pilot users who rely on synchronized favorites, settings, passwords, collections, or other profile data. Existing local profile data is not deleted.
- Use Windows PowerShell 5.1 in 64-bit `System` context.
- Do not simultaneously manage these values to a different state through Settings Catalog, Administrative Templates, security baselines, Group Policy, or another tool.
- Recheck every linked Microsoft applicability table before production rollout because supported versions can change.

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
- Remediation creates missing keys, writes the reviewed value, reads them back, and exits `0` only after exact final validation.
- Logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Edge-Sync-Disabled`.

## Pilot Validation

Use a disposable or nonproduction Windows client in the exact Intune context above.

1. Confirm the device satisfies the linked Microsoft OS, edition, and product-version scope and record its build.
2. Export or record the original key/value state, including registry type and data.
3. Test a missing value; detection must exit `1`.
4. Test the value with the wrong registry type; detection must exit `1`.
5. Test the correct type with wrong data; detection must exit `1`.
6. Set the exact configuration contract; detection must exit `0`.
7. From a restored noncompliant state, let Intune run remediation. It must report success only after the final type and data match.
8. Run detection again, review the package logs and Intune Management Extension logs, then perform the product check: Restart Edge, open `edge://policy`, confirm `SyncDisabled` is enabled, and verify sync is shown as managed and unavailable.
9. Check for policy conflict or reversion after device sync, sign-in where relevant, application restart, and device restart.
10. Restore the recorded original state if the pilot is not approved.

Do not change this package to `Validated` until non-sensitive pilot evidence is recorded using `docs/Trusted-Remediation-Pilot.md`.

## Rollback

Restore every recorded original value with its original type and data. If a value did not exist before the pilot, remove that value only. Remove a key only when the pilot created it and it has no sibling values. Confirm product behavior returns to the intended tenant baseline.

## Troubleshooting

- Confirm Intune used `System` context and 64-bit PowerShell.
- Compare the effective registry type as well as data; a string such as `"0"` is not a DWORD `0`.
- Check Settings Catalog, Administrative Templates, security baselines, Group Policy, and third-party agents for duplicate ownership.
- Review `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` and the package log path above.
- Recheck the linked Microsoft applicability table if the value is exact but the product behavior does not change.

## Microsoft References

- [Microsoft Edge policy documentation](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/syncdisabled)
- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/remediations)
