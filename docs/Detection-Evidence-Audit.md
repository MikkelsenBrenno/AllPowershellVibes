# Detection Evidence Audit

Use `tools\Test-DetectionEvidence.ps1` to review whether detection-style scripts inspect real device evidence or only local marker state.

## Scope

The audit covers:

```text
Custom-Compliance\*\*\Discover.ps1
Detection-Remediation\*\*\Detect.ps1
Win32-Packaged-Scripts\*\*\Detect.ps1
```

Intune Platform Scripts are marked `N/A` because they do not use a detection script contract.

## Evidence Types

| Type | Meaning |
| --- | --- |
| `DirectEvidence` | The script reads a recognized device source such as CIM/WMI, registry, service state, scheduled tasks, event logs, powercfg, OS/storage state, local groups, BitLocker, certificate stores, network configuration, or application inventory. |
| `SnapshotFreshness` | The script validates that a snapshot file exists and is within the configured maximum age. |
| `PackageMarker` | Win32 detection uses a package-owned install or version marker. |
| `MarkerOnly` | The script only reads repository-managed marker state and should not be treated as real device-state compliance without review. |
| `NeedsReview` | The audit could not identify a strong evidence source. |
| `N/A` | The workload does not have a detection script. |

## Commands

Run the audit and write JSON, CSV, and Markdown reports under `output`:

```powershell
.\tools\Test-DetectionEvidence.ps1
```

Update `ScriptInfo.json` evidence metadata:

```powershell
.\tools\Test-DetectionEvidence.ps1 -UpdateScriptInfo
```

Verify evidence metadata is current:

```powershell
.\tools\Test-DetectionEvidence.ps1 -Check
```

Fail when any package still needs evidence review:

```powershell
.\tools\Test-DetectionEvidence.ps1 -FailOnNeedsReview
```

## Review Guidance

Prefer real evidence when a script name implies a real setting, service, registry value, event, file, battery metric, or log snapshot.

Marker-only detection is acceptable when the package is explicitly about marker/package state. Win32 detection can use install markers when the install script owns the marker and the detection is only proving install/version state.
