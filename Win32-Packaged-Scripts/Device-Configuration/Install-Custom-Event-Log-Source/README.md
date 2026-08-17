# Install-Custom-Event-Log-Source

## Summary

Installs a custom Windows event log source and writes a versioned detection marker. This is useful when internal scripts, tools, or scheduled tasks should write identifiable events to the Windows event log.

## Prerequisites

- Package the folder as a Win32 app with the Microsoft Win32 Content Prep Tool.
- Deploy in the system context.
- Choose a unique event source name before production deployment.
- Confirm whether uninstall should remove the event source or only the detection marker.

## Customization

Edit the CONFIGURATION section near the top of the scripts:

- `$EventLogName`: Event log where the source should be created.
- `$EventSourceName`: Unique event source name.
- `$PackageVersion`: Version expected by detection.
- `$MarkerRoot`: Folder where the detection marker is written.
- `$MarkerFileName`: Marker file used by detection.
- `$WriteTestEvent`: Write a test event during install.
- `$RemoveEventSource`: Remove the event source during uninstall.
- `$RemoveMarkerRoot`: Remove the marker folder when empty.

## Intune App Configuration

Program install command:

```text
%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1
```

Program uninstall command:

```text
%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

Detection rules:

1. Choose **Use a custom detection script**.
2. Upload `Detect.ps1`.
3. Set **Run script as 32-bit process on 64-bit clients** to **No**.
4. Set signature enforcement according to your organization's signing policy.

## Expected Results

- Install exits `0` after the event source and marker are present.
- Detection exits `0` and writes STDOUT when the event source registry key and expected marker version are present.
- Detection exits `1` when the event source, marker, or expected version is missing.
- Uninstall exits `0` after the marker is removed and optionally the event source is removed.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Install-Custom-Event-Log-Source`.

## Troubleshooting

- If install fails, verify the event source name is unique.
- If detection fails, confirm `$PackageVersion` matches in `Install.ps1` and `Detect.ps1`.
- If uninstall leaves the event source behind, set `$RemoveEventSource` to `$true`.
- Review Intune Management Extension logs and the package logs together.
