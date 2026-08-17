# Run Disk Cleanup When Low Free Space

## Summary

Detects low free space on the system drive and can remove old files from configurable cleanup folders. This is inspired by common proactive remediation disk cleanup patterns, but defaults to report-only mode.

## Prerequisites

Run in the system context with 64-bit PowerShell. Review cleanup roots carefully before enabling deletion.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$DriveLetter`, `$MinimumFreePercent`, and `$MinimumFreeGB`: Keep these values identical in detection and remediation.
- `$CleanupRoots`: Folders to scan for old files.
- `$MinimumFileAgeDays`: Only files older than this value are targeted.
- `$ApplyCleanup`: Set to `$true` after pilot testing.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Run as system with 64-bit PowerShell.

## Expected Results

Detection exits 1 when free space is below either configured threshold. Remediation stays noncompliant while reporting, then exits 0 only when the final free-space check meets both thresholds and no deletion failed.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Run-Disk-Cleanup-When-Low-Free-Space`. If space remains low after cleanup, review user profile data, update caches, and application-specific logs.

## Credits

Inspired by public Intune remediation disk cleanup patterns. See `docs/Open-Source-Inspiration-And-Credits.md`.
