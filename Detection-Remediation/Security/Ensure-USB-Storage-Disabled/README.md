# Ensure-USB-Storage-Disabled

## Summary

Detects and optionally disables USB mass storage by writing the `USBSTOR` startup registry value. The remediation starts in report-only mode so administrators can review impact before enforcing.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm USB storage exceptions before enforcing.
- Test with pilot devices and user communication.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$UsbStorageRegistryPath`: Registry path for the USB storage driver service.
- `$StartValueName`: Startup value to inspect or write.
- `$ExpectedStartValue`: Expected detection value.
- `$StartValue`: Value written by remediation. Default `4` disables USB storage.
- `$ApplyPolicy`: Set to `$true` in `Remediate.ps1` after pilot testing.
- `$ExitZeroInReportingOnlyMode`: Set to `$true` only when report-only remediation should appear successful.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when USB storage policy matches the expected value.
- Detection exits `1` when the value is missing or different.
- Remediation exits `1` in report-only mode by default.
- Remediation exits `0` after `$ApplyPolicy` is enabled and the value is written.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-USB-Storage-Disabled`.

## Troubleshooting

- If remediation keeps reporting only, verify `$ApplyPolicy` is set to `$true`.
- If the value reverts, check GPO, Settings Catalog, or security baseline assignments.
- If USB storage still works after policy is written, remove and reconnect the USB device or reboot during testing.
- Review the script log for the exact registry path and value used.
