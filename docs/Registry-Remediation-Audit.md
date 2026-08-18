# Registry Remediation Audit

This audit answers a practical technician question: which registry-based Detection and Remediation packages can be copied into Intune with a verified contract, and which ones still need work?

The tracked decision file is `validation/registry-remediation-audit.json`. It covers every Detection-Remediation package whose `Detect.ps1` reads or references Windows registry state. `tools/Test-RegistryRemediationAudit.ps1` rediscovers the candidates on every validation run, so a new registry package cannot be added without an explicit decision.

The standalone `IntuneScriptLibrary-GUI` is a separate tool and is not part of this audit.

## Current Result

Review date: 2026-08-18. Candidate count: 100.

| Disposition | Count | Meaning |
| --- | ---: | --- |
| `PilotReady` | 4 | Microsoft source verified, detection/remediation configuration matches, and exact registry type/data validation is implemented. |
| `NeedsSourceVerification` | 44 | The path, value, data semantics, supported versions/editions, or policy precedence still needs current Microsoft documentation. |
| `PreferNativeManagement` | 12 | The effective state is better managed or measured through a supported CSP, Settings Catalog, Defender, BitLocker, Firewall, service, or other native interface. |
| `MarkerOnly` | 12 | The package checks a repository-owned marker, not the Windows security or configuration state claimed by the name. |
| `InvalidPlaceholder` | 9 | A generated/friendly registry name is not the documented Microsoft policy contract. |
| `NeedsCustomization` | 8 | The package is deliberately tenant-specific or a template and needs an approved local value/strategy. |
| `NeedsRedesign` | 5 | The registry check does not provide reliable evidence for the intended outcome. |
| `Duplicate` | 3 | A better source-backed package already represents the same intent. |
| `OutOfScope` | 3 | The script reads registry inventory but is not a simple registry-policy remediation. |

Warnings are intentional. A held package remains visible and usable as an example, but its audit reason explains why it must not be presented as trusted or pilot-ready.

## Verified First Batch

| Package | Registry contract | Decision note |
| --- | --- | --- |
| `Applications/Ensure-Edge-Password-Manager-Disabled` | `PasswordManagerEnabled`, `REG_DWORD 0` | Use only with an approved credential-management decision, normally another password manager. |
| `Applications/Ensure-Edge-Startup-Boost-Disabled` | `StartupBoostEnabled`, `REG_DWORD 0` | Browser performance choice; measure first-launch impact in the pilot. |
| `Applications/Ensure-Edge-Shopping-Features-Disabled` | `EdgeShoppingAssistantEnabled`, `REG_DWORD 0` | Managed browser-experience choice, not a universal security baseline. |
| `Security/Ensure-Edge-SmartScreen-Enabled` | Four documented SmartScreen values, all `REG_DWORD 1` | Security hardening; confirm supported Edge version and competing policy sources. |

Each package README contains the exact Microsoft Learn sources, supported versions, Intune settings, wrong-type tests, rollback steps, and an `edge://policy` check. `PilotReady` means ready for a controlled nonproduction pilot; it does not mean production-validated.

## Why Type and Data Both Matter

Registry data alone is not a complete policy contract. For example, `REG_SZ` text `"0"` is not the same policy representation as `REG_DWORD 0`, even if simple string conversion makes them look equal.

For a `PilotReady` registry package:

- `Detect.ps1` must be read-only and compare value existence, registry type, and data.
- `$RegistryValues` must be literal and identical in `Detect.ps1` and `Remediate.ps1`.
- `Remediate.ps1` must write the configured type/data and read it back before reporting success.
- A missing key, missing value, wrong type, or wrong data must never be reported as compliant.
- The README must identify policy ownership conflicts and provide reversible pilot steps.

The audit validator enforces these mechanical rules. Microsoft documentation review and pilot evidence remain human decisions recorded in the audit and package README.

## Review Batches

The `Batch` field makes the remaining review manageable:

| Batch | Count | Focus |
| --- | ---: | --- |
| 0 | 30 | Invalid placeholders, duplicates, markers, redesigns, native-management candidates, and out-of-scope registry readers. These need replacement/removal decisions rather than simple source promotion. |
| 1 | 4 | Completed Microsoft Edge first batch. |
| 2 | 21 | Windows device configuration and user-experience policies. |
| 3 | 15 | Defender, Firewall, AutoRun, credentials, and early security policies. |
| 4 | 15 | LSA, PowerShell logging, remote access, SMB, TLS, UAC, USB, and script-host security policies. |
| 5 | 7 | Edge extension, Microsoft 365 Apps/Office, OneDrive, and tenant-specific browser settings. |
| 6 | 8 | Networking and Windows Update policies. |

Review does not automatically mean promotion. A package moves to `PilotReady` only when Microsoft sources support its exact contract, native policy ownership is considered, detection is direct evidence, remediation cannot report false success, and the README contains a safe pilot/rollback plan.

## Technician Workflow

1. Open `validation/registry-remediation-audit.json` and locate the package path.
2. If the disposition is not `PilotReady`, read its `Reason` before copying it. Treat it as an example until the hold is resolved.
3. For `PilotReady`, copy the entire package folder so `Detect.ps1`, `Remediate.ps1`, `README.md`, and `ScriptInfo.json` stay together.
4. Keep the two `$RegistryValues` blocks identical and change only documented configuration values.
5. Follow the package's missing/wrong-type/wrong-data/correct-state pilot cases on a disposable device.
6. Record original registry state before remediation and prove rollback.
7. Confirm the effective policy in the product interface, such as `edge://policy`, not only in Registry Editor.
8. Record pilot evidence before changing repository status from `PilotReady` to `Validated`.

## Validation Commands

```powershell
.\tools\Test-RegistryRemediationAudit.ps1 -SummaryOnly
.\tools\Invoke-Validation.ps1 -Scope Full
```

The audit JSON schema is `validation/registry-remediation-audit.schema.json`. Reasons and sources are public and tenant-neutral; credentials and tenant-specific values never belong in the tracked audit.

## Microsoft References

- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
- [Microsoft Edge browser policy reference](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies)
