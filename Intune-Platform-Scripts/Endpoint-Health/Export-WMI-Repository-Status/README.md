# Export WMI Repository Status

## Summary

This platform script runs WMI repository verification and writes the output to a local JSON snapshot for technician troubleshooting.

## Files

- `Export-WMI-Repository-Status.ps1` - Runs `winmgmt /verifyrepository` and writes the result.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$InventoryRoot` | Folder where the JSON snapshot is written. | `C:\ProgramData\IntuneScriptLibrary\Inventory` |
| `$InventoryFileName` | Output file name. | `WmiRepositoryStatus.json` |
| `$WinMgmtPath` | Path to `winmgmt.exe`. | `%SystemRoot%\System32\wbem\winmgmt.exe` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

Change `$InventoryRoot` if your technicians already use a standard local troubleshooting folder.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Export-WMI-Repository-Status.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy as an on-demand endpoint health troubleshooting helper.

## Expected Results

A JSON file exists at the configured inventory path and contains WMI repository verification output.

## Troubleshooting

- If verification fails, review WMI service state, repository health, and System event logs.
- If `winmgmt.exe` is not found, confirm the device image has standard WMI components.
- Review script logs and Intune Management Extension logs together.
