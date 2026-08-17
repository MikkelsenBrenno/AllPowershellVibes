# Refresh Device Troubleshooting Snapshot

## Summary

Detects whether a local troubleshooting snapshot is missing or stale, then refreshes it with common device, disk, service, update, and recent event information.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm the snapshot folder is acceptable for local technician evidence.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$SnapshotRoot`: Folder where the JSON snapshot is written.
- `$SnapshotFileName`: Snapshot file name.
- `$MaximumSnapshotAgeHours`: Maximum age before detection triggers remediation.
- `$ServicesToReport`: Services included in the snapshot.
- `$DiskDriveLetter`: Drive letter used for disk capacity information.
- `$RecentEventLogMinutes`: Recent System event window.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when the configured snapshot exists and is fresh.
- Detection exits `1` when the snapshot is missing or stale.
- Remediation exits `0` when the snapshot is written successfully.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Refresh-Device-Troubleshooting-Snapshot`.

## Troubleshooting

- Confirm the script context can write to `$SnapshotRoot`.
- If event collection is slow, lower `$RecentEventLogMinutes`.
- If a service always appears missing, confirm the service name is correct.
- Review script logs and Intune Management Extension logs together.
