# Install-Scheduled-Task-From-Script

## Summary

Installs a PowerShell payload as a Windows scheduled task using an Intune Win32 app package. The default payload only writes a last-run marker, making this a safe template for technicians to customize into recurring maintenance or reporting tasks.

## Prerequisites

- Package the folder as a Win32 app with the Microsoft Win32 Content Prep Tool.
- Deploy in the system context.
- Test with a pilot assignment before broad deployment.
- Confirm the task name and payload path do not conflict with existing scheduled tasks.

## Customization

Edit the CONFIGURATION section near the top of the scripts:

- `$TaskName`: Friendly scheduled task name.
- `$TaskPath`: Scheduled Task Scheduler folder path.
- `$TaskDescription`: Description shown in Task Scheduler.
- `$PayloadScriptFileName`: Payload script included in the package.
- `$InstallRoot`: Folder where the payload is copied.
- `$RunAsAccount`: Account used for the scheduled task, usually `SYSTEM`.
- `$ScheduleFrequency`: Use `Daily` or `AtLogon`.
- `$StartTime`: Daily start time in `HH:mm` format.
- `$RemovePayloadFolder`: Controls whether uninstall removes the installed payload folder.
- `TaskPayload.ps1`: Replace the marker-writing example with your real maintenance logic.

## Intune App Commands

- Install command: `powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1`
- Uninstall command: `powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1`
- Detection rule: Use custom detection script `Detect.ps1`
- Install behavior: `System`
- Device restart behavior: `No specific action`

## Expected Results

- Install exits `0` when the scheduled task and payload are present.
- Detection exits `0` and writes STDOUT when the task and payload are detected.
- Detection exits `1` when either the task or payload is missing.
- Uninstall exits `0` when the task is removed or already absent.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Install-Scheduled-Task-From-Script`.

## Troubleshooting

- If detection fails after install, verify `$TaskName`, `$TaskPath`, and `$InstallRoot` match across all scripts.
- If the task does not run, inspect Task Scheduler history and the payload log.
- If daily scheduling fails, confirm `$StartTime` uses `HH:mm` format.
- If uninstall leaves files behind, verify `$RemovePayloadFolder` is set to `$true`.
