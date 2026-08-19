# Trusted Remediation Pilot

This document is the technician handoff for remediation packages that have passed repository review. It does not make a package safe for every tenant: targeting, change approval, and a controlled device pilot are still required.

## Current Trusted Set

| Package | Status | Decision |
| --- | --- | --- |
| `Detection-Remediation/Endpoint-Health/Ensure-Diagnostic-Policy-Service-Running` | `PilotReady` | Detection and remediation use the same `DPS` running-state definition, remediation validates the final state, and report-only mode cannot return false success. |
| `Detection-Remediation/Applications/Ensure-Office-ClickToRun-Service-Running` | `PilotReady` | Detection and remediation use the same exact `Auto` and `Running` state. Target only devices where Office Click-to-Run is installed. |
| `Detection-Remediation/Endpoint-Health/Ensure-Windows-Time-Service-Automatic` | `NeedsReview` | Held because Microsoft documents different Windows Time behavior for domain-joined and workgroup devices. Do not deploy it as a trusted package. |

`PilotReady` means ready for a controlled nonproduction pilot. It does not mean broadly approved. `Validated` requires documented successful testing in the intended context.

## Technician Copy Workflow

Copy the complete package folder to a working location so its README and metadata stay with the scripts. In Intune, upload only the two role files:

| Intune field | File |
| --- | --- |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |

Before upload:

1. Confirm `ScriptInfo.json` says `PilotReady` or `Validated`; stop if it says `Template`, `Planned`, `Example`, or `NeedsReview`.
2. Read the package README, especially prerequisites, `Pilot Validation`, rollback, and targeting exclusions.
3. Compare the `CONFIGURATION` sections in both scripts. Detection and remediation must describe the same state.
4. If a value changes, update both scripts where that value defines expected state. Never change only detection to make a device appear compliant.
5. Use the README's Intune settings. For the current trusted set, use System context and 64-bit Windows PowerShell.
6. Assign only to the documented pilot population. Do not include devices that lack a required service or product.
7. Complete the noncompliant, remediation, and post-detection test before broadening assignment.

Intune runs `Remediate.ps1` only when `Detect.ps1` exits `1`. Detection must remain read-only. Remediation must exit `0` only after it verifies the same state detection expects.

## Promotion Rules

Before setting `PilotReady`:

- The package uses direct evidence from the real managed state.
- Detection is read-only and has honest exit paths.
- Remediation changes only the state named by the package.
- Detection and remediation use the same configuration, context, bitness, and state definition.
- Remediation validates final state and has no false-success path.
- The README contains prerequisites, targeting boundaries, exact Intune settings, a safe pilot procedure, rollback, and relevant Microsoft Learn references.
- All repository validation checks pass.

Before setting `Validated`, add a `## Validation Evidence` section to the package README using the record below. Do not include tenant IDs, device names, usernames, serial numbers, email addresses, or secrets.

## Validation Evidence Record

Copy this table into the package README and replace the example prompts with non-sensitive results:

| Field | Required evidence |
| --- | --- |
| Test date | ISO date (`YYYY-MM-DD`) |
| Repository commit | Commit SHA containing the tested scripts |
| Windows build | Edition and build only; no device identity |
| Device scenario | Join state and required product/prerequisite |
| Execution | System/User context and 32-bit/64-bit host |
| Original state | Relevant values before the test |
| Compliant detection | Exit code and one-line result |
| Noncompliant detection | Exit code and one-line result |
| Remediation | Exit code and verified final state |
| Post-detection | Exit code and one-line result |
| Logs reviewed | Package log and Intune Management Extension log |
| User impact | None, expected impact, or observed issue |
| Rollback | Result of restoring the recorded original state |
| Reviewer | Team/role or initials that do not expose personal data |

Keep raw tenant/device evidence in the organization's approved private system. The public repository should contain only the neutral summary needed to support the `Validated` claim.

## Required Checks

Run from the repository root:

```powershell
.\tools\Test-Repository.ps1
.\tools\Test-IntuneWorkloadContracts.ps1
.\tools\Test-DetectionEvidence.ps1 -Check
.\tools\Test-ScriptPortability.ps1 -Check
.\tools\Update-ScriptCatalog.ps1 -Check
```

Detection smoke tests may execute `Detect.ps1`; repository or CI validation must never execute `Remediate.ps1`.

## Microsoft References

- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
- [PowerShell script execution in Microsoft Intune](https://learn.microsoft.com/en-us/intune/device-management/tools/run-powershell-scripts-windows)

