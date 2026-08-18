# Safe Detection and Discovery Smoke Testing

Use `tools\Test-DetectionSmoke.ps1` to smoke-test only read-only Intune detection/discovery roles. The harness launches each script in a fresh 64-bit Windows PowerShell 5.1 process, enforces a timeout, validates the workload output contract, and writes JSON, CSV, and Markdown reports.

This is not tenant policy validation. A pass proves that the script can launch and satisfy its runtime contract in the isolated test environment. It does not prove what an enrolled production device will report.

## Allowlist

The harness can discover only:

```text
Detection-Remediation\*\*\Detect.ps1
Win32-Packaged-Scripts\*\*\Detect.ps1
Custom-Compliance\*\*\Discover.ps1
```

It never discovers or executes remediation, install, uninstall, or Platform action scripts.

## Isolation

Every child process receives new temporary paths for `ProgramData`, `LOCALAPPDATA`, and `APPDATA`. The temporary tree is removed after the process exits. This prevents normal repository logging and marker paths from writing to the workstation's real profile or ProgramData tree.

Before starting a child process, the harness statically inspects `MAIN`. A missing MAIN section or a state-changing command causes a hard failure and the script is not executed. This applies even when package status is `Example` or `NeedsReview`.

The timeout is 60 seconds by default. A timed-out process is terminated and reported as a failure.

## Commands

List eligible scripts without running them:

```powershell
.\tools\Test-DetectionSmoke.ps1 -Scope AllReadOnly -ListOnly
```

Run changed files through the orchestrator:

```powershell
.\tools\Invoke-Validation.ps1 `
    -Scope Changed `
    -BaseRef origin/main `
    -HeadRef HEAD `
    -EnableSmoke
```

Run an explicit package locally:

```powershell
.\tools\Test-DetectionSmoke.ps1 `
    -Scope CustomCompliance `
    -PackagePath Custom-Compliance/Compliance/Example-Check-BitLocker-Status
```

Important options:

- `-Scope AllReadOnly|AllDetect|Remediation|Win32|CustomCompliance` selects eligible roles. `AllDetect` remains the backward-compatible default.
- `-PackagePath` limits execution to packages.
- `-ScriptPath` limits execution to exact repository-relative scripts.
- `-TimeoutSeconds` controls the per-process timeout.
- `-MaxScripts` limits a local pilot run.
- `-ListOnly` performs discovery without execution.
- `-SummaryOnly` suppresses per-script pass output.
- `-ResultPath` writes the common structured validator result.

## Runtime Contracts

Remediation detection passes when it exits `0` (compliant) or `1` (noncompliant), does not time out, and writes nothing to STDERR.

Win32 detection follows the same exit-code rule, but exit `0` also requires STDOUT so Intune can treat the app as detected.

Custom Compliance discovery must:

- exit `0`;
- write exactly one non-empty output line containing one JSON object;
- return every `SettingName` in `ComplianceRules.json`;
- return values matching each rule's declared `DataType`;
- write nothing to STDERR.

Malformed JSON, multiple output lines, missing rules/keys, mismatched types, invalid exit codes, STDERR, process launch errors, and timeouts are hard failures.

## Reports

The default local reports are:

```text
output\detection-smoke-results.json
output\detection-smoke-results.csv
output\detection-smoke-summary.md
```

See `docs/Validation-Automation.md` for CI selection, aggregate artifacts, and safety boundaries.
