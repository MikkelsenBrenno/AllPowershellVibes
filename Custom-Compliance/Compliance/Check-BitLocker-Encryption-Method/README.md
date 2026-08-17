# Check BitLocker Encryption Method

## Summary

Checks whether the configured BitLocker volume uses an approved encryption method, such as XtsAes128 or XtsAes256. This is useful when technicians need a quick custom compliance rule that reports more detail than simple protection state.

## Prerequisites

Run in the system context on Windows devices with BitLocker management cmdlets available. Test on a small pilot group first because encryption method naming can vary between Windows releases and management baselines.

## Customization

Edit the CONFIGURATION section in `Discover.ps1`.

- `$MountPoint`: Drive to inspect.
- `$AllowedEncryptionMethods`: Encryption methods your organization accepts.

## Intune Settings

Upload `Discover.ps1` as the discovery script and `ComplianceRules.json` as the custom compliance rule file. Use 64-bit PowerShell and run the script as system.

## Expected Results

The discovery script returns compressed JSON with `EncryptionMethodCompliant`, `MountPoint`, `EncryptionMethod`, and `ProtectionStatus`.

## Troubleshooting

Check the local log under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-BitLocker-Encryption-Method`. If results are noncompliant, verify that BitLocker is enabled and confirm the exact encryption method returned by `Get-BitLockerVolume`.
