# Ensure Microsoft 365 Apps Automatic Updates Enabled

## Summary

Detects and remediates the Microsoft 365 Apps computer policy that enables automatic updates.

**Repository status:** `PilotReady`. Microsoft documentation supports the shipped registry contract, and both scripts enforce exact registry type and data. This is ready for a controlled tenant pilot, not pre-labeled as `Validated`.

## Copy To Intune

Copy `Detect.ps1` into the **Detection script** field and `Remediate.ps1` into the **Remediation script** field of one Intune Remediations package. Do not combine or reverse the files.

## Configuration Contract

Keep `$RegistryValues` identical in both scripts.

| Path | Name | Type | Required data |
| --- | --- | --- | --- |
| `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common\OfficeUpdate` | `EnableAutomaticUpdates` | `DWord` | `1` |

**Effect:** Prevents the Office automatic-update policy from disabling Click-to-Run update checks.

## Customization

The shipped contract is the source-verified baseline for this exact package name. Keep `$RegistryValues` identical in both scripts. For a different state, create a separately named and reviewed package so purpose, documentation, risk, and rollback stay honest.

## Prerequisites

- Use only for supported Microsoft 365 Apps Click-to-Run installations.
- Confirm the tenant update authority, servicing channel, maintenance design, and network source before assignment.
- Prefer Cloud Update, Intune, or Office policy for long-term ownership and do not create duplicate policy authorities.
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
- Logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Office-Automatic-Updates-Enabled`.

## Pilot Validation

1. Use a disposable or nonproduction device that satisfies every prerequisite and record its OS and product versions.
2. Export or record the original key/value state, including type and data.
3. Verify detection exits `1` for a missing value, a wrong type, and correct type with wrong data.
4. Set the complete exact contract and verify detection exits `0`.
5. Restore a noncompliant state and let Intune remediate. It must report success only after exact read-back validation.
6. Run detection again and review the package and Intune Management Extension logs.
7. Perform the product check: In an Office app, confirm Update Options are available as designed, trigger Update Now, and verify the Click-to-Run service can discover updates from the approved source.
8. Test required user, application, security, networking, servicing, sign-in, and restart workflows relevant to this package.
9. Check for policy conflict or reversion after device sync, user sign-in, application restart, and device restart where relevant.
10. Restore the original state if the pilot is not approved.

Do not change this package to `Validated` until non-sensitive pilot evidence is recorded using `docs/Trusted-Remediation-Pilot.md`.

## Rollback

Restore every recorded original value with its original type and data. If a value did not exist before the pilot, remove that value only; remove a key only when the pilot created it and it has no sibling values. Restore the previous policy through its owner; disabling automatic updates increases exposure to unpatched Office vulnerabilities.

## Troubleshooting

- Confirm Intune used the documented context and 64-bit PowerShell.
- Compare registry type as well as data; a string `"1"` is not a DWORD `1`.
- Check every supported policy authority for duplicate ownership or higher-precedence configuration.
- Review `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` and the package log.
- Recheck Microsoft applicability and product prerequisites when the registry is exact but behavior differs.

## Microsoft References

- [Troubleshoot automatic updating for Microsoft 365 Apps](https://learn.microsoft.com/en-us/troubleshoot/microsoft-365-apps/installation/automatic-updates)
- [Configure update settings for Microsoft 365 Apps](https://learn.microsoft.com/en-us/microsoft-365-apps/updates/configure-update-settings-microsoft-365-apps)
- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
