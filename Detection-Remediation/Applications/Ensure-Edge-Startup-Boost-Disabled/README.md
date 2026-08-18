# Ensure Edge Startup Boost Disabled

## Summary

Detects and remediates the documented Microsoft Edge Startup Boost policy for organizations that choose to prevent Edge processes from starting at Windows sign-in.

**Repository status:** `PilotReady`. The policy name, path, type, and data are verified against Microsoft Learn, and both scripts validate exact registry type and data. This is an organizational performance policy choice, not a universal Microsoft security recommendation, and it still requires a controlled pilot.

## Files

- `Detect.ps1` checks the policy without changing the device.
- `Remediate.ps1` writes the policy only after detection exits `1`, then verifies the final type and data.

## Configuration Contract

Keep `$RegistryValues` identical in both scripts.

| Path | Name | Type | Required data | Effect |
| --- | --- | --- | --- | --- |
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `StartupBoostEnabled` | `DWord` | `0` | Disables Microsoft Edge Startup Boost. |

`$ValidationDelaySeconds` defaults to `2`. Do not replace the documented policy name with a friendly label.

## Customization

The default registry contract is the verified package purpose. Keep `$RegistryValues` identical in both scripts. Adjust only documented timing or logging configuration; use a separately named and reviewed policy when the intended state is to enable Startup Boost.

## Prerequisites

- Windows device enrolled in Microsoft Intune, using Windows PowerShell 5.1 in 64-bit System context.
- Microsoft Edge 88 or later on Windows, as documented for this policy.
- A pilot that measures sign-in resource use and perceived Edge launch time; disabling Startup Boost can make the first browser launch slower.
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

Assign to a small nonproduction pilot group. Prefer a native Edge Settings Catalog or Administrative Templates policy when it provides the same control and reporting needed by the tenant; do not create competing policy owners.

## Expected Results

- Detection exits `0` only when `StartupBoostEnabled` exists as `REG_DWORD` with data `0`.
- A missing key, missing value, different data, or wrong registry type exits `1`.
- Remediation writes `REG_DWORD 0`, reads it back, and exits `0` only when both type and data match.
- Logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Edge-Startup-Boost-Disabled`.

## Pilot Validation

Use a disposable or nonproduction Windows client in the same System/64-bit context configured in Intune.

1. Record the original key/value existence, type, and data, plus representative Edge launch timing.
2. Verify missing value, wrong type, and wrong DWORD data each make detection exit `1`.
3. Set the exact baseline (`REG_DWORD 0`) and verify detection exits `0`.
4. On the pilot device only, run remediation from a noncompliant state; it must exit `0` only after exact final verification.
5. Run detection again and open `edge://policy` to confirm `StartupBoostEnabled` is loaded without an error.
6. Restart Edge as needed, confirm the user experience is acceptable, review logs, and restore the original registry state.

Do not change this package to `Validated` until pilot evidence is recorded using `docs/Trusted-Remediation-Pilot.md`.

## Rollback

Restore the recorded original type and data. If the value was originally absent, remove `StartupBoostEnabled`. Remove the Edge policy key only if the pilot created it and it is empty.

## Troubleshooting

- Confirm System context and 64-bit PowerShell.
- Check `edge://policy` for the active value, errors, and policy source.
- Look for competing Settings Catalog, Administrative Templates, GPO, or third-party policy.
- Review the package and Intune Management Extension logs.

## Microsoft References

- [StartupBoostEnabled Microsoft Edge policy](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/StartupBoostEnabled) defines the registry path, DWORD type, data values, supported Edge versions, and policy behavior.
- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations) defines the Intune execution model.
