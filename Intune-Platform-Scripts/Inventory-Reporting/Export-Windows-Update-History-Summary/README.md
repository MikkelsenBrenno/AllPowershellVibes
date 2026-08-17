# Export-Windows-Update-History-Summary

## Summary

Exports installed hotfix information and optional recent Windows Update Client events to JSON. This gives technicians a quick support artifact when investigating patch state, failed updates, or recent update activity.

## Prerequisites

- Deploy as an Intune platform script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm local inventory retention expectations with your organization before broad deployment.

## Customization

Edit the CONFIGURATION section near the top of the script:

- `$InventoryRoot`: Folder where the JSON summary is written.
- `$InventoryFileName`: Output file name.
- `$IncludeWindowsUpdateClientEvents`: Include recent Windows Update Client events.
- `$EventLookBackDays`: Time window for Windows Update Client events.
- `$MaxUpdateEvents`: Maximum number of update events collected.
- `$WindowsUpdateClientEventIds`: Event IDs included in the summary.
- `$MaxMessageLength`: Maximum event message length written to JSON.

## Intune Settings

- Script: `Export-Windows-Update-History-Summary.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`
- Assignment: Start with a pilot group before broad deployment.

## Expected Results

- Script exits `0` when the summary file is written.
- Script exits `1` when export fails before writing the summary.
- Inventory is written to `C:\ProgramData\IntuneScriptLibrary\Inventory\WindowsUpdateHistorySummary.json` by default.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-Windows-Update-History-Summary`.

## Troubleshooting

- If event query fails, check `EventQueryError` in the JSON output.
- If output is too large, reduce `$EventLookBackDays`, `$MaxUpdateEvents`, or `$MaxMessageLength`.
- If expected events are missing, verify `$WindowsUpdateClientEventIds` includes the event IDs you need.
- Compare the JSON output with Update History and Event Viewer during pilot testing.
