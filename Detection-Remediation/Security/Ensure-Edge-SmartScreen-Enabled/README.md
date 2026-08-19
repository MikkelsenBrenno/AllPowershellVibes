# Ensure Edge SmartScreen Enabled

## Summary

Detects and remediates four documented Microsoft Edge policies that enable Microsoft Defender SmartScreen, enable potentially unwanted app blocking, and prevent users from overriding SmartScreen warnings for sites and downloads.

**Repository status:** `PilotReady`. Every policy name, path, type, and data value is verified against Microsoft Learn, and both scripts validate exact registry type and data. The package requires a controlled pilot before it can be marked `Validated`.

## Files

- `Detect.ps1` checks all four policies without changing the device.
- `Remediate.ps1` writes the policies only after detection exits `1`, then verifies every final type and data value.

## Configuration Contract

Keep `$RegistryValues` identical in both scripts. All values use `HKLM:\SOFTWARE\Policies\Microsoft\Edge`.

| Name | Type | Required data | Effect |
| --- | --- | --- | --- |
| `SmartScreenEnabled` | `DWord` | `1` | Enables Microsoft Defender SmartScreen. |
| `SmartScreenPuaEnabled` | `DWord` | `1` | Enables SmartScreen blocking for potentially unwanted apps. |
| `PreventSmartScreenPromptOverride` | `DWord` | `1` | Prevents bypass of SmartScreen site warnings. |
| `PreventSmartScreenPromptOverrideForFiles` | `DWord` | `1` | Prevents bypass of SmartScreen download warnings. |

`$ValidationDelaySeconds` defaults to `2`. Do not substitute friendly labels for the Microsoft policy identifiers.

## Customization

The four-value set is the verified package contract. Keep `$RegistryValues` identical in both scripts. Removing a value changes the security outcome and requires a separate Microsoft source review, package name/summary review, and pilot decision.

## Prerequisites

- Windows device enrolled in Microsoft Intune, using Windows PowerShell 5.1 in 64-bit System context.
- A supported Microsoft Edge release. Microsoft documents `SmartScreenEnabled` and both override policies for Edge 77 and later, and `SmartScreenPuaEnabled` for Edge 80 and later on Windows.
- Target supported managed Windows editions and enrollment states described on the Microsoft policy pages.
- No Settings Catalog, Administrative Templates, security baseline, Defender policy, GPO, or other tool intentionally managing these same policies to a different state.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run using logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

Assign to a small nonproduction pilot group first. Prefer supported native Edge policy controls when they provide the required reporting, and keep one intentional owner per setting.

## Expected Results

- Detection exits `0` only when all four values exist as `REG_DWORD` with data `1`.
- A missing key/value, wrong type, or different data for any value exits `1`.
- Remediation writes all four DWORD values, reads them back, and exits `0` only when every type and value matches.
- Edge can require a policy refresh or restart before its UI reflects the state.
- Logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Edge-SmartScreen-Enabled`.

## Pilot Validation

Use a disposable or nonproduction Windows client in the same System/64-bit context configured in Intune.

1. Record the original existence, type, and data for all four values.
2. Test a missing value, a wrong DWORD value, and a wrong type such as `REG_SZ` containing `1`; detection must exit `1` in every case.
3. Set all four exact DWORD baselines and verify detection exits `0`.
4. On the pilot device only, run remediation from a noncompliant state. It must exit `0` only after exact verification of all four values.
5. Run detection again and open `edge://policy`; confirm all four policies are loaded without errors and show the intended source/value.
6. Exercise an approved SmartScreen test scenario without downloading or running untrusted content, review logs, and restore the original state.

Do not change this package to `Validated` until pilot evidence is recorded using `docs/Trusted-Remediation-Pilot.md`.

## Rollback

Restore each recorded original type and data. Remove only values that were absent before the pilot. Remove the Edge policy key only if the pilot created it and it is empty; never remove unrelated Edge policies.

## Troubleshooting

- Confirm System context and 64-bit PowerShell.
- Use `edge://policy` to identify parse errors, unexpected sources, or conflicting policy owners.
- Check Settings Catalog, Administrative Templates, security baselines, Defender policy, GPO, and third-party agents.
- Review the package and Intune Management Extension logs.

## Microsoft References

- [SmartScreenEnabled Microsoft Edge policy](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/SmartScreenEnabled)
- [SmartScreenPuaEnabled Microsoft Edge policy](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/SmartScreenPuaEnabled)
- [PreventSmartScreenPromptOverride Microsoft Edge policy](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/PreventSmartScreenPromptOverride)
- [PreventSmartScreenPromptOverrideForFiles Microsoft Edge policy](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/PreventSmartScreenPromptOverrideForFiles)
- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
