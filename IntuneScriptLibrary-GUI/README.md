# Intune Script Library GUI

Standalone Windows PowerShell 5.1 WinForms picker for the Microsoft Intune PowerShell Script Library.

The tool searches a local copy of the script library, lets technicians customize existing Detection and Remediation packages, previews the final files, and exports a full package folder under `Generated-Packages`.

## Start

Run from Windows PowerShell 5.1:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Start-IntuneScriptLibraryGui.ps1
```

On first launch, choose the local script library root. That root should contain the `Detection-Remediation` folder.

## Workflow

1. Select the local repository root.
2. Click `Load`.
3. Search or filter packages by category, risk, or context.
4. Select a package.
5. Review the overview details, description, editable configuration summary, and deployment/troubleshooting notes.
6. Use the Configure tab to select a setting and edit it in the guided editor.
7. Review the generated preview.
8. Click `Generate Package`.

Generated packages are written here:

```text
IntuneScriptLibrary-GUI\Generated-Packages\<PackageName>
```

The export copies the full selected package, including `README.md`, `ScriptInfo.json`, and any package assets, then applies the edited configuration values to `Detect.ps1` and `Remediate.ps1`.

## Overview Tab

The overview tab is meant for quick technician triage before editing:

- `Package Details` shows metadata from `ScriptInfo.json`.
- `Description` shows the package summary.
- `Editable Configuration` lists the technician-facing settings first, using friendly names instead of raw PowerShell variable assignments.
- `Show advanced/internal settings` is available directly in Overview and is mirrored on the Configure tab.
- `Deployment And Troubleshooting Notes` pulls the most useful sections from the package README.

## Editing Notes

- The Configure tab shows a compact setting list and a guided editor for the selected setting.
- Matching settings used by both `Detect.ps1` and `Remediate.ps1` are collapsed into one row and updated together.
- Internal identity values such as `$ScriptPackageName`, `$ScriptName`, and `$PurposeCategory` are hidden by default.
- Use `Show advanced/internal settings` in either Overview or Configure when you need every variable from the `CONFIGURATION` block.
- String values are shown without quotes and exported as single-quoted PowerShell strings.
- Boolean values use an `Enabled / True` or `Disabled / False` dropdown.
- Numbers are exported as entered.
- Simple lists are edited one item per line and exported as PowerShell arrays.
- Common `Join-Path -Path $env:... -ChildPath ...` paths are shown as friendly paths like `$env:ProgramData\Folder`.
- Advanced expressions are still shown as expressions and should only be changed by someone comfortable with PowerShell syntax.
- The tool validates the generated `Detect.ps1` and `Remediate.ps1` syntax before export.

## Validation Helpers

These non-GUI modes are useful for quick checks:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Start-IntuneScriptLibraryGui.ps1 -RepositoryRoot .. -IndexOnly
powershell.exe -ExecutionPolicy Bypass -File .\Start-IntuneScriptLibraryGui.ps1 -RepositoryRoot .. -ExportPackage Ensure-Local-Administrators-State -Force
```

Version 1 supports Detection and Remediation packages only.
