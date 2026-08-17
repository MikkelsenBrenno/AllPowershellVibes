# Backup BitLocker Recovery Key To Entra

## Summary

Detects whether a BitLocker recovery password protector exists and can attempt to back it up to Entra ID using BitLocker PowerShell cmdlets. Optional event-log checking can be enabled if your environment records backup events consistently.

## Prerequisites

Run in the system context with 64-bit PowerShell on Entra joined or hybrid joined devices. Test carefully because BitLocker backup behavior depends on device join state and policy configuration.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$MountPoint`: BitLocker volume to inspect.
- `$RequireRecentBackupEvent`: Enables event-log validation.
- `$MaximumBackupEventAgeDays`: Event lookback window.
- `$CreateRecoveryPasswordProtectorIfMissing`: Optional protector creation.
- `$ApplyBackupAction`: Set to `$true` after pilot testing.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Run as system with 64-bit PowerShell.

## Expected Results

Detection exits 0 when a recovery password protector exists and optional backup event validation passes. Remediation reports intended backup actions until `$ApplyBackupAction` is enabled.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Backup-BitLocker-Recovery-Key-To-Entra`. If backup fails, verify device join state, BitLocker protector state, and BitLocker Management event logs.

## Credits

Inspired by public BitLocker recovery key backup remediation examples. See `docs/Open-Source-Inspiration-And-Credits.md`.
