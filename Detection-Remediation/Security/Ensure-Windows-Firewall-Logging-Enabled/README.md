# Ensure Windows Firewall Logging Enabled

## Summary

Detects whether Windows Firewall profile logging matches expected settings and can configure log settings. This is useful when technicians need local packet logging for endpoint firewall troubleshooting or audit readiness.

## Prerequisites

Run in the system context with 64-bit PowerShell. Confirm expected log size and log collection policy before enabling remediation.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$ProfilesToCheck` or `$ProfilesToConfigure`: Firewall profiles to manage.
- `$RequireBlockedLogging` and `$SetBlockedLogging`: Dropped packet logging.
- `$RequireAllowedLogging` and `$SetAllowedLogging`: Successful connection logging.
- `$ExpectedLogFileName` and `$LogFileName`: Firewall log path.
- `$ApplyFirewallLoggingChange`: Set to `$true` after pilot testing.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Run as system with 64-bit PowerShell.

## Expected Results

Detection exits 0 when all configured firewall profiles match the expected logging settings. Remediation reports intended changes until `$ApplyFirewallLoggingChange` is enabled.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Windows-Firewall-Logging-Enabled`. If firewall logs are not written, confirm the profile is active and the log folder exists.

## Credits

Inspired by public Intune remediation firewall audit/logging patterns. See `docs/Open-Source-Inspiration-And-Credits.md`.
