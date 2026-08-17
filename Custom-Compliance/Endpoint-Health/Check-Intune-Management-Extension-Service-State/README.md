# Check-Intune-Management-Extension-Service-State

## Summary

Reports whether the Intune Management Extension service exists, uses the expected startup mode, and is running. This is useful for finding devices that may fail Win32 app installs, remediations, or PowerShell script delivery.

## Prerequisites

- Deploy as an Intune custom compliance discovery script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Use only on devices expected to have the Intune Management Extension installed.

## Customization

Edit the CONFIGURATION section near the top of `Discover.ps1`:

- `$ServiceName`: Intune Management Extension service name.
- `$RequireRunning`: Set to `$false` if you only want to validate service presence and startup mode.
- `$AllowedStartModes`: Startup modes considered compliant.

## Intune Settings

- Discovery script: `Discover.ps1`
- Rules file: `ComplianceRules.json`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Output is compressed JSON.
- `IntuneManagementExtensionServiceCompliant` is `true` when the service matches the configured policy.
- `ServiceStartMode` and `ServiceState` show the raw service values.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Intune-Management-Extension-Service-State`.

## Troubleshooting

- If `ServiceExists` is `false`, confirm the device is targeted by Intune Management Extension workloads.
- If the service is stopped, review Intune Management Extension logs.
- If startup mode differs, check hardening baselines or local service changes.
- Use this check together with the IME restart remediation package for pilot troubleshooting.
