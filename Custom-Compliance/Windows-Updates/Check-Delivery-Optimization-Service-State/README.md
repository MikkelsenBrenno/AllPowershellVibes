# Check-Delivery-Optimization-Service-State

## Summary

Reports whether the Delivery Optimization service exists and is not disabled. This helps technicians find devices where Windows Update or Microsoft Store content delivery may be impaired.

## Prerequisites

- Deploy as an Intune custom compliance discovery script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Use on Windows client devices that include the Delivery Optimization service.

## Customization

Edit the CONFIGURATION section near the top of `Discover.ps1`:

- `$ServiceName`: Delivery Optimization service name. Default is `DoSvc`.
- `$RequireRunning`: Set to `$true` only if your policy requires the service to be running at discovery time.
- `$AllowedStartModes`: Startup modes considered compliant.

## Intune Settings

- Discovery script: `Discover.ps1`
- Rules file: `ComplianceRules.json`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Output is compressed JSON.
- `DeliveryOptimizationCompliant` is `true` when the service exists and matches the configured state policy.
- `ServiceStartMode` and `ServiceState` show the raw service values.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Delivery-Optimization-Service-State`.

## Troubleshooting

- If `ServiceExists` is `false`, verify the device is a supported Windows client build.
- If `ServiceStartMode` is `Disabled`, use a remediation package or configuration profile to re-enable the service.
- If `$RequireRunning` is enabled, remember that trigger-start services may not always be running.
- Review the discovery log for the exact service state returned by WMI.
