# Ensure WMI Service Healthy

## Summary

Detects and repairs Windows Management Instrumentation service state. This is useful when inventory, compliance, or Intune scripts fail because local WMI service health has drifted.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm WMI repository repair is not required before relying on service-only remediation.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$ServiceName`: Service to inspect or repair.
- `$RequireRunning`: Whether detection requires the service to be running.
- `$AllowedStartModes`: Startup modes allowed by detection.
- `$StartupType`: Startup type remediation applies.
- `$StartServiceAfterChange`: Whether remediation starts the service.
- `$ValidationDelaySeconds`: Delay before post-remediation validation.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when WMI service state matches expectations.
- Detection exits `1` when WMI service is missing, stopped, disabled, or otherwise noncompliant.
- Remediation exits `0` when startup type and service state validate successfully.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-WMI-Service-Healthy`.

## Troubleshooting

- If WMI queries still fail after remediation, verify repository consistency separately.
- If the service will not start, review System event logs and service dependencies.
- If policy disables the service again, check GPO, baseline, or hardening tools.
- Review script logs and Intune Management Extension logs together.
