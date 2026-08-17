# Check-Defender-Tamper-Protection-State

## Summary

Reports whether Microsoft Defender tamper protection appears enabled according to `Get-MpComputerStatus`. The script also reports whether the tamper protection property is available on the target device.

## Prerequisites

- Deploy as an Intune custom compliance discovery script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Use on devices where Microsoft Defender Antivirus status cmdlets are available.

## Customization

Edit the CONFIGURATION section near the top of `Discover.ps1`:

- `$ExpectedTamperProtectedState`: Expected Defender tamper protection state.
- `$TreatMissingPropertyAsNonCompliant`: Treat devices without the property as noncompliant.

Also update `ComplianceRules.json` if your expected state changes.

## Intune Settings

- Discovery script: `Discover.ps1`
- Rules file: `ComplianceRules.json`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Output is compressed JSON.
- `DefenderTamperProtectionCompliant` is `true` when tamper protection matches policy.
- `TamperProtectionPropertyAvailable` shows whether the device exposed the status property.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Defender-Tamper-Protection-State`.

## Troubleshooting

- If the property is missing, verify Defender platform support and management channel.
- If tamper protection is off, review Defender for Endpoint and Intune security policy assignment.
- If `Get-MpComputerStatus` is unavailable, confirm Defender is present and the device is supported.
- Compare discovery output with Defender security portal state during pilot testing.
