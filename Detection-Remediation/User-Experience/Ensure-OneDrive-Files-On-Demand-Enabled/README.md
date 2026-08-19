# Ensure OneDrive Files On-Demand Enabled

## Summary

Detects and remediates the OneDrive machine policy that enables Files On-Demand.

**Repository status:** `PilotReady`. Microsoft documentation supports the shipped registry contract, and both scripts enforce exact registry type and data. This is ready for a controlled tenant pilot, not pre-labeled as `Validated`.

## Copy To Intune

Copy `Detect.ps1` into the **Detection script** field and `Remediate.ps1` into the **Remediation script** field of one Intune Remediations package. Do not combine or reverse the files.

## Configuration Contract

Keep `$RegistryValues` identical in both scripts.

| Path | Name | Type | Required data |
| --- | --- | --- | --- |
| `HKLM:\SOFTWARE\Policies\Microsoft\OneDrive` | `FilesOnDemandEnabled` | `DWord` | `1` |

**Effect:** Makes new OneDrive sync relationships use online-only placeholders by default so content downloads when opened.

## Customization

The shipped contract is the source-verified baseline for this exact package name. Keep `$RegistryValues` identical in both scripts. For a different state, create a separately named and reviewed package so purpose, documentation, risk, and rollback stay honest.

## Prerequisites

- Install and support the current OneDrive sync app on Windows 10 version 1709 or later or Windows 11.
- Confirm the Windows Cloud Files Filter Driver is operational; this package intentionally does not change its service start value.
- Test applications that require files to remain locally available and manage those files or folders explicitly.
- Use Windows PowerShell 5.1 in 64-bit `System` context.
- Do not simultaneously manage these values to a different state through Intune policy, security baselines, Group Policy, Cloud Policy, or another tool.

## Intune Settings

| Setting | Required/recommended value |
| --- | --- |
| Workload | Remediations |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run using logged-on credentials | No |
| Enforce script signature check | Follow tenant signing policy |
| Run script in 64-bit PowerShell | Yes |

Assign a small, representative nonproduction group first. Intune runs remediation only when detection exits `1`.

## Expected Results

- Detection is read-only and exits `0` only when every value exists with the exact required registry type and data.
- A missing key, missing value, wrong type, wrong data, or read error exits `1`.
- Remediation writes the reviewed values, reads them back, and exits `0` only after exact final validation.
- Logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-OneDrive-Files-On-Demand-Enabled`.

## Pilot Validation

1. Use a disposable or nonproduction device that satisfies every prerequisite and record its OS and product versions.
2. Export or record the original key/value state, including type and data.
3. Verify detection exits `1` for a missing value, a wrong type, and correct type with wrong data.
4. Set the complete exact contract and verify detection exits `0`.
5. Restore a noncompliant state and let Intune remediate. It must report success only after exact read-back validation.
6. Run detection again and review the package and Intune Management Extension logs.
7. Perform the product check: Sign in to OneDrive, confirm Files On-Demand is policy-enabled, verify online-only placeholders appear, and open a test file to confirm hydration succeeds.
8. Test required user, application, security, networking, servicing, sign-in, and restart workflows relevant to this package.
9. Check for policy conflict or reversion after device sync, user sign-in, application restart, and device restart where relevant.
10. Restore the original state if the pilot is not approved.

Do not change this package to `Validated` until non-sensitive pilot evidence is recorded using `docs/Trusted-Remediation-Pilot.md`.

## Rollback

Restore every recorded original value with its original type and data. If a value did not exist before the pilot, remove that value only; remove a key only when the pilot created it and it has no sibling values. Restoring the prior policy does not automatically change every existing file hydration state; plan storage and user impact.

## Troubleshooting

- Confirm Intune used the documented context and 64-bit PowerShell.
- Compare registry type as well as data; a string `"1"` is not a DWORD `1`.
- Check every supported policy authority for duplicate ownership or higher-precedence configuration.
- Review `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` and the package log.
- Recheck Microsoft applicability and product prerequisites when the registry is exact but behavior differs.

## Microsoft References

- [OneDrive policies - Files On-Demand](https://learn.microsoft.com/en-us/sharepoint/use-group-policy#use-onedrive-files-on-demand)
- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
