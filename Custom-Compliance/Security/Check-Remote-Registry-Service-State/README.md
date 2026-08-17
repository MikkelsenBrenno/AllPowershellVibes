# Check-Remote-Registry-Service-State

## Summary

Reports whether the Remote Registry service is disabled and stopped. This gives technicians a focused signal for a common Windows hardening setting.

## Prerequisites

- Deploy as an Intune custom compliance discovery script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm whether any administrative tooling requires Remote Registry before enforcing.

## Customization

Edit the CONFIGURATION section near the top of `Discover.ps1`:

- `$ServiceName`: Remote Registry service name.
- `$ExpectedStartMode`: Startup mode considered compliant. Default is `Disabled`.
- `$RequireStopped`: Require the service state to be `Stopped`.

## Intune Settings

- Discovery script: `Discover.ps1`
- Rules file: `ComplianceRules.json`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Output is compressed JSON.
- `RemoteRegistryServiceCompliant` is `true` when startup mode and state match policy.
- `ServiceStartMode` and `ServiceState` show the raw service values.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Remote-Registry-Service-State`.

## Troubleshooting

- If the service is running, check whether management tooling started it.
- If the startup mode keeps reverting, review GPO, Settings Catalog, or hardening baselines.
- If the service is missing, confirm the target OS supports it.
- Use the matching remediation package only after exception review.
