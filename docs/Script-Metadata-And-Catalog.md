# Script Metadata And Catalog

Each deployable script package includes `ScriptInfo.json`. The repository catalog is generated from these metadata files.

## Required Fields

| Field | Purpose |
| --- | --- |
| `Name` | Display name in the catalog. |
| `Workload` | Intune workload family. |
| `Purpose` | Purpose category folder. |
| `Status` | Example, Template, or Planned. |
| `Context` | System, User, or mixed guidance. |
| `Requires64BitPowerShell` | 64-bit recommendation or requirement. |
| `HasRemediation` | Yes, No, Reporting only, or N/A. |
| `HasUninstall` | Yes or No. |
| `TeamsAlertReady` | Whether the package includes Teams alerting support. |
| `WritesTo` | What the script changes or outputs. |
| `Reboot` | Whether a reboot is expected. |
| `Risk` | Low, Medium, or High. |
| `Summary` | Short catalog summary. |
| `Tags` | Optional search tags. |

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
.\tools\Update-ScriptCatalog.ps1 -Check
```

If the catalog check fails, regenerate `SCRIPT-CATALOG.md` and commit the result.
