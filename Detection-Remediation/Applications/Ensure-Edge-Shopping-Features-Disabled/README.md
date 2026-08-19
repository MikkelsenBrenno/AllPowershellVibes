# Ensure Edge Shopping Features Disabled

## Summary

Detects and remediates the documented Microsoft Edge shopping assistant policy for organizations that choose not to expose shopping features in the managed browser.

**Repository status:** `PilotReady`. The policy name, path, type, and data are verified against Microsoft Learn, and both scripts validate exact registry type and data. This is an organizational browser-experience choice, not a universal security baseline, and it still requires a controlled pilot.

## Files

- `Detect.ps1` checks the policy without changing the device.
- `Remediate.ps1` writes the policy only after detection exits `1`, then verifies the final type and data.

## Configuration Contract

Keep `$RegistryValues` identical in both scripts.

| Path | Name | Type | Required data | Effect |
| --- | --- | --- | --- | --- |
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `EdgeShoppingAssistantEnabled` | `DWord` | `0` | Disables shopping assistant features in Microsoft Edge. |

`$ValidationDelaySeconds` defaults to `2`. The registry name is the Microsoft policy identifier and should not be renamed.

## Customization

The default registry contract is the verified package purpose. Keep `$RegistryValues` identical in both scripts. Adjust only documented timing or logging configuration; use a separately named and reviewed policy when the intended state is to enable shopping features.

## Prerequisites

- Windows device enrolled in Microsoft Intune, using Windows PowerShell 5.1 in 64-bit System context.
- Microsoft Edge 87 or later on Windows, as documented for this policy.
- An approved browser-experience decision for the targeted users.
- No Settings Catalog, Administrative Templates, GPO, or other tool intentionally managing the same value to a different state.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run using logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

Assign to a small nonproduction pilot group. Prefer native Edge policy management when it meets the same requirement, and avoid assigning two tools as owners of the same policy.

## Expected Results

- Detection exits `0` only when `EdgeShoppingAssistantEnabled` exists as `REG_DWORD` with data `0`.
- A missing key, missing value, different data, or wrong registry type exits `1`.
- Remediation writes `REG_DWORD 0`, reads it back, and exits `0` only when both type and data match.
- Logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Edge-Shopping-Features-Disabled`.

## Pilot Validation

Use a disposable or nonproduction Windows client in the same System/64-bit context configured in Intune.

1. Record the original key/value existence, type, and data.
2. Verify missing value, wrong type, and wrong DWORD data each make detection exit `1`.
3. Set the exact baseline (`REG_DWORD 0`) and verify detection exits `0`.
4. On the pilot device only, run remediation from a noncompliant state; it must exit `0` only after exact final verification.
5. Run detection again and open `edge://policy` to confirm `EdgeShoppingAssistantEnabled` is loaded without an error.
6. Confirm the intended shopping UI is unavailable, review logs, and restore the original registry state.

Do not change this package to `Validated` until pilot evidence is recorded using `docs/Trusted-Remediation-Pilot.md`.

## Rollback

Restore the recorded original type and data. If the value was originally absent, remove `EdgeShoppingAssistantEnabled`. Remove the Edge policy key only if the pilot created it and it is empty.

## Troubleshooting

- Confirm System context and 64-bit PowerShell.
- Check `edge://policy` for the active value, errors, and policy source.
- Look for competing Settings Catalog, Administrative Templates, GPO, or third-party policy.
- Review the package and Intune Management Extension logs.

## Microsoft References

- [EdgeShoppingAssistantEnabled Microsoft Edge policy](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/EdgeShoppingAssistantEnabled) defines the registry path, DWORD type, data values, supported Edge versions, and policy behavior.
- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations) defines the Intune execution model.
