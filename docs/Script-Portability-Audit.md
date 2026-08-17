# Script Portability Audit

Use `tools\Test-ScriptPortability.ps1` to review whether PowerShell scripts avoid language-dependent, OS-display-name-dependent, and non-scalable patterns.

## Scope

The audit covers deployable package scripts and PowerShell templates:

```text
Custom-Compliance\*\*\*.ps1
Detection-Remediation\*\*\*.ps1
Intune-Platform-Scripts\*\*\*.ps1
Win32-Packaged-Scripts\*\*\*.ps1
templates\*.ps1
```

## Risk Areas

| Area | Meaning |
| --- | --- |
| `Localization` | Localized built-in groups/accounts such as Administrators, Users, Everyone, or NT AUTHORITY\SYSTEM. |
| `OsVersion` | Hardcoded Windows display versions or ProductName/Caption decisions. |
| `CommandParsing` | Human-readable command output parsing from tools such as powercfg, netsh, dsregcmd, or reagentc. |
| `Scalability` | Unbounded recursive filesystem scans, whole-log reads, or Win32_Product usage. |
| `RegistryView` | Ambiguous 32-bit/64-bit registry view access. |
| `PathAssumption` | Fixed profile or Program Files paths instead of discovered paths or environment APIs. |

## Commands

Run the audit and write JSON, CSV, and Markdown reports under `output`:

```powershell
.\tools\Test-ScriptPortability.ps1
```

Update package `ScriptInfo.json` portability metadata:

```powershell
.\tools\Test-ScriptPortability.ps1 -UpdateScriptInfo
```

Refresh the committed baseline when current findings are intentional:

```powershell
.\tools\Test-ScriptPortability.ps1 -UpdateBaseline
```

Verify metadata and block new high or medium findings not in the baseline:

```powershell
.\tools\Test-ScriptPortability.ps1 -Check
```

## Review Guidance

Prefer well-known SIDs for built-in principals, CIM/registry/event IDs or documented APIs over localized command text, EditionID/build/UBR over Windows display names, and bounded scans with max depth, max item count, max age, or explicit root scope.
