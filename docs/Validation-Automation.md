# Validation Automation

This document defines how repository changes are validated. It complements `Intune-Workload-Contracts.md`, which remains the source of truth for choosing a workload and implementing its Intune behavior. Microsoft Learn remains authoritative for product behavior and limits.

The standalone `IntuneScriptLibrary-GUI` is outside this validation system. Do not add GUI paths, tests, or deployment behavior to this workflow.

## Quick Start

Validate only packages changed between two refs:

```powershell
.\tools\Invoke-Validation.ps1 `
    -Scope Changed `
    -BaseRef origin/main `
    -HeadRef HEAD
```

Run full static validation:

```powershell
.\tools\Invoke-Validation.ps1 -Scope Full
```

Run full validation and the safe read-only smoke policy:

```powershell
.\tools\Invoke-Validation.ps1 -Scope Full -EnableSmoke
```

Write reports somewhere else:

```powershell
.\tools\Invoke-Validation.ps1 -Scope Full -OutputRoot C:\Temp\IntuneValidation
```

The entry point supports `-Scope Changed|Full`, `-BaseRef`, `-HeadRef`, `-TenantProfilePath`, `-EnableSmoke`, `-OutputRoot`, and `-CI`.

## Changed Scope

Changed scope reads `git diff --name-status -M <base> <head>` and maps files below a workload to the first three path segments:

```text
<Workload>/<Purpose>/<Package>
```

A script, README, rule, or metadata change validates that package. A rename records both the source and destination package paths. Deleted packages have no checkout directory to execute, but remain in the report and are covered by the always-on catalog check.

Changed validation escalates to full validation when:

- the base or head ref cannot be resolved;
- more than 100 packages are affected;
- a validator, validation module, template, workflow, workload contract, test, or shared JSON schema changes.

The exact escalation reason is written to both reports.

## Validator Interface

The static validators accept the following common options while retaining their previous defaults:

- `-PackagePath <path[]>` limits package-level work;
- `-SummaryOnly` suppresses normal pass-by-pass console output;
- `-ResultPath <file>` writes a structured result with validator counts and rule-level results.

`Update-ScriptCatalog.ps1 -Check` is always global. A changed package may add, remove, rename, or change metadata that affects the generated catalog.

## Reports

The output folder contains:

- `validation-results.json`: requested/effective scope, refs, escalation, timing, counts, validator summaries, and sorted rule-level results;
- `validation-summary.md`: totals and the first 20 failures/warnings;
- `pester-results.xml`: NUnit XML from Pester;
- validator-specific JSON, CSV, and Markdown evidence where applicable.

Reports use stable property order and sorted findings. Timestamps and durations naturally vary by run.

## Safe Smoke Policy

Smoke execution is intentionally allowlisted. The runner can discover only:

- `Detection-Remediation/*/*/Detect.ps1`;
- `Win32-Packaged-Scripts/*/*/Detect.ps1`;
- `Custom-Compliance/*/*/Discover.ps1`.

It cannot discover or execute `Remediate.ps1`, `Install.ps1`, `Uninstall.ps1`, or any Platform action script.

Each eligible script runs in a fresh 64-bit Windows PowerShell 5.1 child process with a 60-second timeout. `ProgramData`, `LOCALAPPDATA`, and `APPDATA` point to a new temporary directory for that process and are removed afterward.

Before launch, the runner inspects the script's `MAIN` section and refuses execution when it is missing or contains a state-changing command pattern. This preflight applies to every status, including `Example` and `NeedsReview`.

Runtime contracts:

- Remediation detection may exit `0` for compliant or `1` for noncompliant.
- Win32 detection may exit `1` for not detected. Exit `0` also requires STDOUT.
- Custom Compliance discovery must exit `0`, write exactly one JSON object, and return every `SettingName` in `ComplianceRules.json` with the declared data type.
- STDERR, invalid exit codes, malformed/multiple JSON output, missing keys, type mismatches, and timeouts fail the smoke run.

On pull requests and pushes, smoke selection is limited to changed eligible files. A manually dispatched full smoke run intentionally evaluates all eligible read-only files.

## Tenant Profiles

A tenant profile validates a checkout; it never edits a script, calls Intune, or deploys anything. The public repository remains tenant-neutral.

Start from `validation/tenant-profile.example.json` and save the real profile using a name such as `tenant-profile.contoso.local.json`. Files matching `tenant-profile*.local.json` are ignored. Never put secrets, tokens, credentials, or private certificates in a profile.

Each package entry contains:

- `Path`: repository-relative package path;
- `AllowedStatuses`: normally `PilotReady` and `Validated`;
- `ExpectedContext`: the expected `ScriptInfo.json` context;
- optional `ConfigurationAssertions`: `Script`, `Variable`, and `Equals`.

Configuration values are read through the PowerShell parser AST. Scripts are not executed. Literal strings, numbers, booleans, nulls, and arrays of those values are supported. Missing variables, duplicate assignments, commands, variable references, interpolation, and other computed expressions fail clearly.

The validator rejects unknown properties, duplicate package paths, nonexistent packages, invalid/incorrect statuses, context mismatches, and assertion mismatches. The tracked schema is `validation/tenant-profile.schema.json`.

## Adding or Changing a Package

1. Select the workload using `docs/Intune-Workload-Contracts.md` and the linked Microsoft documentation.
2. Keep the public package tenant-neutral and all editable values in `CONFIGURATION`.
3. Update the package README and `ScriptInfo.json`.
4. Refresh evidence/portability metadata when logic changes.
5. Regenerate `SCRIPT-CATALOG.md` when metadata or package paths change.
6. Run changed validation against the intended base ref.
7. Promote to `PilotReady` or `Validated` only when strict workload, evidence, portability, and runtime expectations are satisfied.

## CI Schedule

- Pull requests: changed-package static validation with automatic full escalation.
- Pushes to `main`: full static validation plus safe smoke for eligible scripts changed by the push.
- Sunday 03:00 UTC: full static validation with no package execution.
- Manual dispatch: full static validation with optional full safe smoke execution.

Superseded runs for the same pull request are cancelled. Reports are uploaded for 14 days, and the Markdown summary is added to the GitHub job summary.

CI installs exactly Pester 5.9.0. See the [Pester installation guide](https://pester.dev/docs/v5/introduction/installation) and [Pester 5.9.0 package](https://www.powershellgallery.com/packages/Pester/5.9.0).

## Microsoft References

- [Remediations in Microsoft Intune](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
- [Use PowerShell scripts on Windows devices in Intune](https://learn.microsoft.com/en-us/intune/device-management/tools/run-powershell-scripts-windows)
- [Custom compliance discovery scripts](https://learn.microsoft.com/en-us/intune/device-security/compliance/create-custom-script)
- [Custom compliance JSON files](https://learn.microsoft.com/en-us/intune/device-security/compliance/create-custom-json)
- [Add and assign Win32 apps](https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32)
