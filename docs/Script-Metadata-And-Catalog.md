# Script Metadata And Catalog

Each deployable script package includes `ScriptInfo.json`. The repository catalog is generated from these metadata files.

## Required Fields

| Field | Purpose |
| --- | --- |
| `Name` | Display name in the catalog. |
| `Workload` | Intune workload family. |
| `Purpose` | Topical category folder, such as Security or Compliance. This is not an Intune workload. |
| `Status` | Template, Planned, Example, NeedsReview, PilotReady, or Validated. |
| `Context` | System, User, or mixed guidance. |
| `Requires64BitPowerShell` | 64-bit recommendation or requirement. |
| `HasRemediation` | Yes, No, Reporting only, or N/A. |
| `HasUninstall` | Yes or No. |
| `TeamsAlertReady` | Whether the package includes Teams alerting support. |
| `WritesTo` | What the script changes or outputs. |
| `Reboot` | Whether a reboot is expected. |
| `Risk` | Low, Medium, or High. |
| `DetectionEvidenceType` | DirectEvidence, MarkerOnly, PackageMarker, SnapshotFreshness, NeedsReview, or N/A. |
| `DetectionEvidenceSource` | Short description of the source used by detection or discovery logic. |
| `DetectionReviewStatus` | Reviewed, NeedsReview, or NotApplicable. |
| `PortabilityReviewStatus` | Reviewed, NeedsReview, or NotApplicable. |
| `PortabilityRiskLevel` | None, Low, Medium, or High. |
| `PortabilityRiskAreas` | Localization, OsVersion, CommandParsing, Scalability, RegistryView, or PathAssumption findings. Empty when no risks are detected. |
| `PortabilityNotes` | Short review note from the portability audit. |
| `Summary` | Short catalog summary. |
| `Tags` | Optional search tags. |

## Status Promotion

New packages start as `Template`. `Example`, `Planned`, and `NeedsReview` packages are not deployable promises. Packages marked `PilotReady` or `Validated` must pass `tools\Test-IntuneWorkloadContracts.ps1`, including the evidence, portability, and readiness-documentation gates described in `docs/Intune-Workload-Contracts.md`. `Validated` also requires non-sensitive test evidence in the package README.

## Generate The Catalog

Run:

```powershell
.\tools\Update-ScriptCatalog.ps1
```

To create starter metadata for folders that do not have `ScriptInfo.json` yet:

```powershell
.\tools\Update-ScriptCatalog.ps1 -InitializeMissingScriptInfo
```

## CI Check

GitHub Actions runs:

```powershell
.\tools\Test-Repository.ps1
.\tools\Test-IntuneWorkloadContracts.ps1
.\tools\Update-ScriptCatalog.ps1 -Check
```

If the catalog check fails, regenerate `SCRIPT-CATALOG.md` and commit the result.

## Detection Evidence Audit

Run:

```powershell
.\tools\Test-DetectionEvidence.ps1
```

After changing detection or discovery logic, update evidence metadata and regenerate the catalog:

```powershell
.\tools\Test-DetectionEvidence.ps1 -UpdateScriptInfo
.\tools\Update-ScriptCatalog.ps1
```

CI verifies current evidence metadata with:

```powershell
.\tools\Test-DetectionEvidence.ps1 -Check
```

## Script Portability Audit

Run:

```powershell
.\tools\Test-ScriptPortability.ps1
```

After changing script logic, update portability metadata and regenerate the catalog:

```powershell
.\tools\Test-ScriptPortability.ps1 -UpdateScriptInfo -UpdateBaseline
.\tools\Update-ScriptCatalog.ps1
```

CI verifies current portability metadata and blocks new high or medium findings that are not in the committed baseline:

```powershell
.\tools\Test-ScriptPortability.ps1 -Check
```
