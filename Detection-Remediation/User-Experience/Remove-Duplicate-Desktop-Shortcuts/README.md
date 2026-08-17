# Remove Duplicate Desktop Shortcuts

## Summary

Detects duplicate `.lnk` or `.url` desktop shortcuts across configured desktop folders and can remove duplicates. The remediation is report-only by default so technicians can review the exact files first.

## Prerequisites

Run in the user context when targeting the signed-in user's desktop. Run as system only if you intentionally target public desktop items.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$DesktopRoots`: Desktop folders to scan.
- `$ShortcutExtensions`: Shortcut file extensions to include.
- `$ApplyShortcutRemoval`: Set to `$true` after pilot testing.
- `$KeepNewestShortcut`: Keep newest duplicate when enabled.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Use user context for per-user desktop cleanup.

## Expected Results

Detection exits 1 when duplicate shortcut file names are found. Remediation reports removal targets until `$ApplyShortcutRemoval` is enabled.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Remove-Duplicate-Desktop-Shortcuts`. If duplicates remain, confirm both desktop paths are included in `$DesktopRoots`.
