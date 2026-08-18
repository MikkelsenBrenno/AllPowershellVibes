# Repository Instructions For Codex

These instructions apply to the entire repository.

## Intune Workload Contract

Before creating, moving, or materially changing an Intune script package, read `docs/Intune-Workload-Contracts.md` completely.

- Choose the workload by how Microsoft Intune executes the package, not by its topic or folder name.
- Treat `Purpose` in `ScriptInfo.json` as a topical category only. It is not a workload.
- Use `tools\New-IntuneScriptFolder.ps1` for new package scaffolds when practical.
- New packages remain `Template`, `Planned`, `Example`, or `NeedsReview` until implementation and review are complete.
- Do not promote a package to `PilotReady` or `Validated` unless `tools\Test-IntuneWorkloadContracts.ps1` and the other repository checks pass.
- Never present marker-only evidence, placeholder state, or an uncollected local report as the real state named by a package.

Workload essentials:

- Remediations require `Detect.ps1` and `Remediate.ps1`. Detection reads real state and exit `1` conditionally triggers repair. Remediation changes that same state and validates the result.
- Platform scripts contain one standalone action script. Do not use them for recurring drift evaluation.
- Custom Compliance requires `Discover.ps1` and `ComplianceRules.json`. Discovery is read-only except for local diagnostic logging, returns one compressed JSON object, and leaves compliance thresholds to the rules file.
- Win32 packaged scripts use application-style install, uninstall, and detection behavior.

When Microsoft Intune behavior, limits, portal paths, or required JSON fields might have changed, verify them against current official Microsoft Learn documentation before editing code or documentation. Update the review date in `docs/Intune-Workload-Contracts.md` when that contract is reverified.

## Required Checks

Run checks relevant to the change. Before completing a new or promoted script package, run:

```powershell
.\tools\Test-Repository.ps1
.\tools\Test-IntuneWorkloadContracts.ps1
.\tools\Test-DetectionEvidence.ps1 -Check
.\tools\Test-ScriptPortability.ps1 -Check
.\tools\Update-ScriptCatalog.ps1 -Check
```

Detection and discovery logic changes also require evidence metadata to be regenerated and reviewed. Intentional portability changes require their metadata and baseline to be updated according to `docs/Script-Metadata-And-Catalog.md`.

## Standalone GUI Boundary

`IntuneScriptLibrary-GUI` is a standalone tool. Do not modify it as part of repository script taxonomy, workload-contract, metadata, catalog, or package cleanup work unless the user explicitly requests a GUI change.
