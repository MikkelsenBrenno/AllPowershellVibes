# Check Windows Update Pending Reboot

## Summary

Reports whether common Windows Update and servicing locations show a pending reboot. This gives helpdesk teams a simple compliance signal for devices that need a restart before updates can continue.

## Prerequisites

Run in the system context. Registry reboot indicators can remain until Windows completes servicing, so pilot the rule before using it for broad compliance reporting.

## Customization

Edit the CONFIGURATION section in `Discover.ps1`.

- `$RebootRequiredPaths`: Registry paths used as reboot signals.
- `$PendingFileRenameValueName`: Session Manager value used for pending file rename checks.

## Intune Settings

Upload `Discover.ps1` as the discovery script and `ComplianceRules.json` as the custom compliance rule file. Use 64-bit PowerShell and run the script as system.

## Expected Results

The discovery script returns compressed JSON with `NoWindowsUpdatePendingReboot`, `PendingReboot`, and `MatchedSignals`.

## Troubleshooting

Check the local log under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Windows-Update-Pending-Reboot`. If a device remains noncompliant after restart, review CBS and Windows Update logs for stuck servicing actions.
