# Ensure Cached Domain Logons Limited

## Summary

Detects whether cached domain logons are above a configured maximum and can set the Winlogon `CachedLogonsCount` value. This is useful for security baselines where offline domain credential caching should be limited.

## Prerequisites

Run in the system context with 64-bit PowerShell. Pilot carefully on remote or travel-heavy devices because this setting can affect offline sign-in behavior.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$MaximumCachedLogonsCount`: Detection threshold.
- `$TargetCachedLogonsCount`: Remediation target.
- `$ApplyRegistryChange`: Set to `$true` after pilot testing.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Run as system with 64-bit PowerShell.

## Expected Results

Detection exits 0 when the cached logon count is at or below the configured maximum. Remediation reports the intended registry change until `$ApplyRegistryChange` is enabled.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Cached-Domain-Logons-Limited`. If users report offline sign-in issues, review the configured count and device connectivity requirements.

## Credits

Inspired by public Intune remediation security-baseline patterns. See `docs/Open-Source-Inspiration-And-Credits.md`.
