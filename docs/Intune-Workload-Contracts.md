# Intune Workload Contracts

This document is the repository source of truth for choosing and implementing an Intune script workload. Microsoft Learn remains the authoritative product documentation. Recheck the linked Microsoft documentation when Intune behavior changes.

Last reviewed against Microsoft Learn: 2026-08-17.

## Choose The Workload By Deployment Behavior

Choose the workload before choosing the topical category or writing code.

| Required outcome | Repository workload | Deployable unit |
| --- | --- | --- |
| Detect drift and conditionally repair it, either once or on a schedule | `Detection-Remediation` | `Detect.ps1` and `Remediate.ps1` |
| Discover device values and let an Intune compliance policy evaluate them | `Custom-Compliance` | `Discover.ps1` and `ComplianceRules.json` |
| Run one standalone action after assignment or after the script/policy changes | `Intune-Platform-Scripts` | One named `.ps1` file |
| Install something with application-style detection and uninstall behavior | `Win32-Packaged-Scripts` | `Install.ps1`, `Uninstall.ps1`, and `Detect.ps1` |

`Purpose` in `ScriptInfo.json` is the topical category, such as `Security`, `Compliance`, or `Storage-Disk`. It is not the Intune workload. For example, a package can have workload `Detection and Remediation` and purpose category `Compliance` without being a Custom Compliance package.

## Detection And Remediation Contract

Use this workload when Intune should evaluate current state and run a repair only when the target problem exists.

Required behavior:

- `Detect.ps1` reads the real state that the package claims to manage.
- Detection exits `0` when no repair is required.
- Detection exits `1` when the target issue is present. Microsoft Intune runs remediation only for detection exit code `1`.
- `Remediate.ps1` changes the same state checked by detection.
- Remediation validates the final state before exiting `0`.
- Remediation exits nonzero when the change or final validation fails.
- Detection and remediation use the same configuration values, context assumptions, registry view, and state definition.
- Do not use a repository-created marker as a substitute for the claimed state. A marker is acceptable only when possession of that marker is itself the documented requirement.
- Do not put reboot commands in these scripts. Report that a reboot is required and manage it through an appropriate deployment workflow.

Remediations are not inherently one-time. Assignment schedules can be Once, Hourly, or Daily.

Microsoft reference: [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations).

## Platform Script Contract

Use this workload for one standalone script that performs an action without a detection/remediation handshake.

Required behavior:

- The package contains one primary PowerShell script.
- The script performs a complete, meaningful action and validates success when practical.
- Exit `0` means the action completed successfully; nonzero means it failed.
- The script must be smaller than the current Microsoft platform-script upload limit.
- Do not use a Platform script when recurring drift evaluation is required. Use Remediations instead.
- Do not describe a local JSON file as centralized reporting unless another documented process collects it.

After a Platform script succeeds, it normally does not run again unless the script or policy changes. A failed script is retried during the next three consecutive Intune Management Extension check-ins. Device-assigned scripts can also run for new users depending on assignment and context, so package documentation must describe its targeting assumptions.

Microsoft reference: [Use PowerShell scripts on Windows devices in Intune](https://learn.microsoft.com/en-us/intune/device-management/tools/run-powershell-scripts-windows).

## Custom Compliance Contract

Use this workload when Intune must evaluate settings that are not available in its built-in compliance settings.

Required behavior:

- `Discover.ps1` discovers device values. It must not remediate or change the managed state. Writing local diagnostic logs is allowed.
- The discovery script returns one compressed JSON object to standard output.
- Do not write status, progress, warning, or debug text to standard output alongside the JSON.
- Prefer returning observed values, such as `SystemDriveFreeGB`, instead of calculating a generic `IsCompliant` value in the script. `ComplianceRules.json` should own the compliance threshold.
- Each rule `SettingName` matches a returned JSON property exactly, including case.
- Each rule has `SettingName`, `Operator`, `DataType`, `Operand`, `MoreInfoUrl`, and `RemediationStrings`.
- `RemediationStrings` includes at least one `en_US` entry.
- Operators and data types use values supported by Microsoft Intune.
- The discovery script, output, rule count, rule-file size, and execution duration remain within the current Microsoft limits.

Each discovery script can be associated with only one compliance policy, and each compliance policy can include only one discovery script. A script can return multiple settings for that policy.

Custom Compliance marks device compliance state. Blocking access requires a Microsoft Entra Conditional Access policy that uses compliant-device state; Custom Compliance alone does not block every device connection.

Microsoft references:

- [Create Custom Compliance discovery scripts](https://learn.microsoft.com/en-us/intune/device-security/compliance/create-custom-script)
- [Create Custom Compliance JSON files](https://learn.microsoft.com/en-us/intune/device-security/compliance/create-custom-json)
- [Use custom compliance settings](https://learn.microsoft.com/en-us/intune/device-security/compliance/custom-settings)

## Companion Packages

One scenario can have more than one workload package only when every package has an independent, honest role.

Example for disk space:

- Custom Compliance returns `SystemDriveFreeGB`; its JSON rule defines the required minimum.
- Remediation detects the same free-space condition, performs an approved cleanup, and measures free space again.
- A Platform script is appropriate only for a deliberate standalone action, such as establishing a scheduled cleanup task. A script that merely writes an uncollected local report is not a substitute for either workload.

Do not generate one package per workload simply to fill the catalog.

## Package Readiness

`ScriptInfo.json` uses `Status` as the promotion gate:

| Status | Meaning |
| --- | --- |
| `Template` | Generated scaffold. It contains unfinished workload logic and must not be deployed. |
| `Planned` | Named scenario that has not been implemented. |
| `Example` | Learning or experimental implementation. Review every line before use. |
| `NeedsReview` | Implemented, but a workload, evidence, portability, or safety review is incomplete. |
| `PilotReady` | Contract checks pass and the package is ready only for controlled pilot testing. |
| `Validated` | Contract checks pass and documented testing has been completed. Tenant-specific approval is still required. |

The repository validator applies strict semantic gates to `PilotReady` and `Validated`. Marker-only evidence, unfinished placeholders, missing Custom Compliance rule fields, mismatched workload metadata, or an unreviewed evidence classification prevents promotion.

## Adding A New Script

1. Read the decision table above and select the workload by execution behavior.
2. Generate the folder with `tools\New-IntuneScriptFolder.ps1`. New packages start as `Template`.
3. Replace every `IMPLEMENT WORKLOAD LOGIC` section with real device-state logic.
4. Complete the package README and `ScriptInfo.json`.
5. For detection or discovery, update and review evidence metadata.
6. Test syntax, failure paths, exit codes, execution context, registry view, and final-state validation.
7. Run the repository checks:

```powershell
.\tools\Test-Repository.ps1
.\tools\Test-IntuneWorkloadContracts.ps1
.\tools\Test-DetectionEvidence.ps1 -Check
.\tools\Test-ScriptPortability.ps1 -Check
.\tools\Update-ScriptCatalog.ps1 -Check
```

8. Change `Status` to `PilotReady` only after the strict checks pass and the package is ready for a controlled pilot.
9. Change `Status` to `Validated` only after documented testing succeeds. This status never removes the need for tenant change control and security review.

## Review Questions

Before promoting a package, answer all of these:

- Does the workload match how Intune actually invokes the package?
- Does the script inspect the state named by the package, rather than a synthetic marker?
- Does detection/discovery avoid changing managed state?
- Does an action script validate what it changed?
- Do exit codes and standard output match this workload's contract?
- Does the README state whether execution is recurring, conditional, standalone, or compliance-driven?
- Are all Microsoft limits and portal settings documented?
- Has the script been tested in its intended user/system and 32-bit/64-bit context?
