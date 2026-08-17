# Export Device Health Attestation State

## Summary

Exports local Secure Boot, TPM, BitLocker, and OS build signals that are useful when troubleshooting Business Premium compliance and device health readiness.

## Prerequisites

Run as system with 64-bit PowerShell. Some values may be unavailable on virtual machines or legacy BIOS devices.

## Customization

Edit the CONFIGURATION section in `Export-Device-Health-Attestation-State.ps1`.

- `$OutputRoot`: Folder where JSON output is written.
- `$OutputFileName`: Output file name.
- `$SystemDriveMountPoint`: Volume used for BitLocker checks.

## Intune Settings

Upload `Export-Device-Health-Attestation-State.ps1` as an Intune platform script. Run as system with 64-bit PowerShell.

## Expected Results

The script writes `DeviceHealthAttestationState.json` and exits 0 when export succeeds.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-Device-Health-Attestation-State`. If Secure Boot is blank, confirm the device uses UEFI and supports Secure Boot.
