# Defender Enable Network Protection Block Mode

## Summary

Enables Microsoft Defender Network Protection in block mode.

**Repository status:** `PilotReady`. Detection reads direct Microsoft Defender preference evidence, remediation uses `Set-MpPreference` and verifies the final preference before reporting success. Product operation still requires controlled tenant pilot evidence.

**Ownership warning:** This overlaps `Ensure-Defender-Network-Protection-Enabled`. Assign either the registry package or this Defender-cmdlet package, never both.

## Copy To Intune

Copy `Detect.ps1` into the **Detection script** field and `Remediate.ps1` into the **Remediation script** field of one Intune Remediations package. Never combine or reverse the two scripts.

## Configuration Contract

The shipped contract is `EnableNetworkProtection = Enabled`. Keep the configuration values identical in both scripts.

**Effect:** Configures Network Protection to block connections to malicious or suspicious network destinations instead of audit-only behavior.

## Customization

The shipped values are the source-reviewed baseline represented by this package name. If your tenant needs another mode, create a separately named package and repeat the documentation and pilot review instead of silently changing the meaning of this package.

## Prerequisites

- Confirm supported Windows or Windows Server scope, Defender Antivirus platform health, cloud protection, required connectivity, and any server-specific allow settings. Pilot line-of-business web and network traffic for false positives.
- Run as 64-bit Windows PowerShell 5.1 in `System` context.
- Use one authoritative management source. Do not assign this package when Intune Endpoint security Antivirus policy, Defender security settings management, Configuration Manager, Group Policy, or another package owns the same preference.
- Do not disable tamper protection to make remediation pass. If tamper protection or another management source rejects the change, remediation must fail its final read-back and the conflict must be resolved in the owning management plane.
- Recheck the linked Microsoft applicability and prerequisite guidance before production rollout.

## Intune Settings

| Setting | Required/recommended value |
| --- | --- |
| Workload | Remediations |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run using logged-on credentials | No |
| Enforce script signature check | Follow tenant signing policy |
| Run script in 64-bit PowerShell | Yes |

Assign first to a small, representative nonproduction device group. Intune runs remediation only after detection exits `1`.

## Expected Results

- Detection is read-only and exits `0` only when the Defender preference contract matches.
- Missing Defender cmdlets, missing or null preference data, an unexpected value, or a read failure exits `1`.
- Remediation writes only the documented Defender preference contract and exits `0` only after direct final read-back matches.
- Logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Defender-Enable-Network-Protection`.

## Pilot Validation

1. Use a disposable or nonproduction supported Windows device and record OS build, Defender platform/engine versions, `AMRunningMode`, `AntivirusEnabled`, and tamper-protection state from `Get-MpComputerStatus`.
2. Record the original values returned by `Get-MpPreference` and identify every policy source that can own them.
3. Confirm detection exits `1` for an intentionally nonmatching preference and for an unavailable or null preference fixture in test automation.
4. Set the exact shipped contract and confirm detection exits `0`.
5. Restore a noncompliant state and let Intune run remediation. It must return success only after final read-back matches.
6. Perform the product check: Confirm `Get-MpPreference`.EnableNetworkProtection resolves to `Enabled`, verify Defender Antivirus is active, then use the documented Network Protection demonstration or event validation procedure.
7. Review Defender operational events, Intune Management Extension logs, package logs, security alerts, application compatibility, and performance.
8. Sync policy and restart where operationally appropriate; confirm the value does not revert because of another management source.
9. Restore the recorded tenant state if the pilot is rejected.

Do not change this package to `Validated` until non-sensitive pilot evidence is recorded using `docs/Trusted-Remediation-Pilot.md`.

## Rollback

Restore the exact original Defender preference through its authoritative management source. Confirm the preference read-back and active product state, not only the local command result. Do not weaken tamper protection as a rollback mechanism.

## Troubleshooting

- Confirm `Get-MpComputerStatus` reports Microsoft Defender Antivirus in the expected active mode; a configured preference can exist while the product is passive.
- Confirm the Defender PowerShell module exposes every required property and parameter on the pilot platform version.
- Review tamper protection and policy-management conflicts when `Set-MpPreference` returns without producing the required final state.
- Review `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` and the package log above.
- Use Intune Endpoint security Antivirus policy as the preferred owner when it exposes the same supported setting.

## Microsoft References

- [Set-MpPreference](https://learn.microsoft.com/en-us/powershell/module/defender/set-mppreference?view=windowsserver2025-ps)
- [Microsoft Defender Network Protection](https://learn.microsoft.com/en-us/defender-endpoint/enable-network-protection)
- [Troubleshoot tamper protection](https://learn.microsoft.com/en-us/defender-endpoint/troubleshoot-problems-with-tamper-protection)
- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/remediations)