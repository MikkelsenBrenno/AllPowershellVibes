# Check-USB-Storage-Policy

## Summary

Reports whether the USB mass storage driver startup value matches your policy. By default, the check expects `USBSTOR` startup value `4`, which is commonly used to block USB storage devices.

## Prerequisites

- Deploy as an Intune custom compliance discovery script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm whether any device groups are allowed to use USB storage before enforcing.

## Customization

Edit the CONFIGURATION section near the top of `Discover.ps1`:

- `$UsbStorageRegistryPath`: Registry path for the USB storage driver service.
- `$StartValueName`: Startup value name.
- `$ExpectedStartValue`: Expected startup value. Default `4` means disabled.

Also update `ComplianceRules.json` if the expected startup value changes.

## Intune Settings

- Discovery script: `Discover.ps1`
- Rules file: `ComplianceRules.json`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Output is compressed JSON.
- `UsbStoragePolicyCompliant` is `true` when the registry value matches the expected value.
- `UsbStorageStartValue` shows the raw registry value.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-USB-Storage-Policy`.

## Troubleshooting

- If the registry path is missing, verify the device OS and USB storage driver state.
- If the value is `3`, USB storage is usually allowed.
- If compliance and script results disagree, verify the script expected value and rules file operand match.
- Use the matching remediation package only after pilot testing and exception review.
