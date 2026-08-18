# Ensure Edge Password Manager Disabled

## Summary

Detects and remediates the documented Microsoft Edge policy that disables the built-in password manager. Use this package only where the organization has approved another password manager or has explicitly decided not to allow password storage.

**Repository status:** `PilotReady`. The policy name, path, type, and data are verified against Microsoft Learn, and both scripts validate exact registry type and data. The package still requires a controlled pilot before it can be marked `Validated`.

## Files

- `Detect.ps1` checks the policy without changing the device.
- `Remediate.ps1` writes the policy only after detection exits `1`, then verifies the final type and data.

## Configuration Contract

Keep `$RegistryValues` identical in both scripts.

| Path | Name | Type | Required data | Effect |
| --- | --- | --- | --- | --- |
| `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `PasswordManagerEnabled` | `DWord` | `0` | Disables saving new passwords in Microsoft Edge. |

`$ValidationDelaySeconds` defaults to `2`. Do not change the registry name to a friendly label; the name above is the Microsoft policy contract.

## Customization

The default registry contract is the verified package purpose. Keep `$RegistryValues` identical in both scripts. If the tenant wants Edge password storage enabled, do not invert and deploy this package under its current name; use native Edge policy management or create a separately reviewed package whose name and documentation match that intent.

## Prerequisites

- Windows device enrolled in Microsoft Intune, using Windows PowerShell 5.1 in 64-bit System context.
- A supported Microsoft Edge release. Microsoft documents this policy for Microsoft Edge 77 and later on Windows.
- An approved credential-management decision. Disabling the Edge password manager without an alternative can encourage unsafe user workarounds.
- No Settings Catalog, Administrative Templates, security baseline, GPO, or other tool intentionally managing the same value to a different state.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run using logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

Assign to a small nonproduction pilot group before wider deployment. Do not also configure the same Edge policy elsewhere unless the duplicate management is deliberate and uses the same value.

## Expected Results

- Detection exits `0` only when `PasswordManagerEnabled` exists as `REG_DWORD` with data `0`.
- A missing key, missing value, different data, or wrong registry type exits `1` and requests remediation.
- Remediation creates the key if required, writes `REG_DWORD 0`, reads it back, and exits `0` only when both type and data match.
- Logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Edge-Password-Manager-Disabled`.

## Pilot Validation

Use a disposable or nonproduction Windows client in the same System/64-bit context configured in Intune.

1. Record whether the key and value exist, including the original value type and data.
2. Test the missing-value case; detection must exit `1`.
3. Create the value as the wrong type, such as `REG_SZ` containing `0`; detection must still exit `1`.
4. Test a wrong DWORD value; detection must exit `1`.
5. Set the exact baseline (`REG_DWORD 0`); detection must exit `0`.
6. On the pilot device only, run remediation from a noncompliant state. It must exit `0` only after the final type and data match.
7. Run detection again, review the package logs, and open `edge://policy` to confirm Edge reads `PasswordManagerEnabled` without an error.
8. Restore the recorded original state after the test.

Do not change this package to `Validated` until pilot evidence is recorded using `docs/Trusted-Remediation-Pilot.md`.

## Rollback

Restore the recorded original type and data. If the value did not exist before the pilot, remove `PasswordManagerEnabled`. Remove the Edge policy key only if it was created by the pilot and is empty; never remove sibling policies.

## Troubleshooting

- Confirm Intune ran the scripts as System in 64-bit PowerShell.
- Check `edge://policy` for policy errors and the policy source.
- Check Settings Catalog, Administrative Templates, security baselines, GPO, and third-party agents for competing management.
- Review the Intune Management Extension logs in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.

## Microsoft References

- [PasswordManagerEnabled Microsoft Edge policy](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/PasswordManagerEnabled) defines the registry path, DWORD type, data values, supported Edge versions, and policy behavior.
- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations) defines the Intune detection/remediation execution model.
