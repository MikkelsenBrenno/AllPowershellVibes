# Check-Windows-Time-Service-State

## Summary

Reports Windows Time service startup mode, service state, and time source. This helps technicians identify devices that may have authentication, certificate, VPN, or update issues caused by incorrect time sync.

## Prerequisites

- Deploy as an Intune custom compliance discovery script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm whether your environment allows `Local CMOS Clock` before enforcing.

## Customization

Edit the CONFIGURATION section near the top of `Discover.ps1`:

- `$ServiceName`: Windows Time service name.
- `$RequireRunning`: Require the service to be running at discovery time.
- `$AllowedStartModes`: Startup modes considered compliant.
- `$AllowLocalCmosClockSource`: Set to `$true` if Local CMOS Clock is acceptable in your environment.

## Intune Settings

- Discovery script: `Discover.ps1`
- Rules file: `ComplianceRules.json`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Output is compressed JSON.
- `WindowsTimeServiceCompliant` is `true` when service state and time source match your policy.
- `TimeSource` shows the raw output from `w32tm.exe /query /source`.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Windows-Time-Service-State`.

## Troubleshooting

- If `LocalCmosClockDetected` is `true`, run the Windows Time repair remediation or review domain/NTP settings.
- If the service is missing or disabled, verify the Windows Time service has not been hardened incorrectly.
- If `$RequireRunning` is enabled, remember that some environments use trigger-start behavior.
- Compare discovery output with `w32tm /query /status` during pilot testing.
