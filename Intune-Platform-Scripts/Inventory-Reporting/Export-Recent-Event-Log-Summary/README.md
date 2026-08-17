# Export-Recent-Event-Log-Summary

## Summary

Exports recent critical and error events from configurable Windows event logs to JSON. The output gives technicians a quick support artifact for troubleshooting without manually opening Event Viewer on the device.

## Prerequisites

- Deploy as an Intune platform script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm local inventory retention expectations with your organization before broad deployment.

## Customization

Edit the CONFIGURATION section near the top of the script:

- `$InventoryRoot`: Folder where the JSON summary is written.
- `$InventoryFileName`: Output file name.
- `$LogNames`: Event logs to query.
- `$LookBackHours`: Time window for recent events.
- `$EventLevelIds`: Event level IDs to include. Default `1,2` means Critical and Error.
- `$MaxEventsPerLog`: Maximum events collected per log.
- `$MaxMessageLength`: Maximum event message length written to JSON.

## Intune Settings

- Script: `Export-Recent-Event-Log-Summary.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`
- Assignment: Start with a pilot group before broad deployment.

## Expected Results

- Script exits `0` when the summary file is written.
- Script exits `1` when export fails before writing the summary.
- Inventory is written to `C:\ProgramData\IntuneScriptLibrary\Inventory\RecentEventLogSummary.json` by default.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-Recent-Event-Log-Summary`.

## Troubleshooting

- If a log query fails, check `LogSummaries` in the JSON output for the exact error.
- If output is too large, reduce `$LookBackHours`, `$MaxEventsPerLog`, or `$MaxMessageLength`.
- If events are missing, verify `$EventLevelIds` includes the levels you expect.
- Compare the JSON output with Event Viewer during pilot testing.
