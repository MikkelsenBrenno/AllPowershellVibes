# Intune Platform Scripts

Use this category for standalone PowerShell scripts deployed through Intune platform scripts.

Platform scripts are useful for one-time setup tasks or simple configuration changes. For recurring drift correction, use `Detection-Remediation` instead.

## Folder Standard

```text
Intune-Platform-Scripts/
`-- <Purpose-Category>/
    `-- <Script-Name>/
        |-- <Verb-Noun>.ps1
        `-- README.md
```

## Purpose Categories

- `Security`
- `Compliance`
- `Device-Configuration`
- `Applications`
- `Maintenance`
- `Endpoint-Health`
- `Networking`
- `User-Experience`
- `Inventory-Reporting`
- `Windows-Updates`

## Script Rules

- Keep the script self-contained.
- Put editable values in the `CONFIGURATION` section.
- Validate the final state before exiting `0`.
- Log to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\<ScriptPackageName>\<ScriptName>.log`.
- Exit `1` when the requested state cannot be confirmed.

## Intune Settings

Recommended defaults:

| Setting | Recommendation |
| --- | --- |
| Run using logged-on credentials | No for device-level settings |
| Run script in 64-bit PowerShell host | Yes for machine-level settings |
| Enforce script signature check | Match your organization's signing policy |

## Examples

| Folder | Purpose |
| --- | --- |
| `Device-Configuration/Example-Set-TimeZone` | Sets and validates the Windows time zone |

## Add a New Platform Script

1. Choose the correct purpose category.
2. Copy the nearest example or create a starter folder with `tools/New-IntuneScriptFolder.ps1`.
3. Rename the folder and script using verb-noun naming.
4. Update the README before publishing.
5. Test in the same context selected in Intune.
