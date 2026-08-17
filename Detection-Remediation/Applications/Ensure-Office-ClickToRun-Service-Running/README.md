# Ensure Office ClickToRun Service Running

## Summary

Detects and repairs Microsoft Office Click-to-Run service state. This helps with Office update, repair, and launch issues where `ClickToRunSvc` is disabled or stopped.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Run in 64-bit PowerShell.
- Microsoft 365 Apps or Office Click-to-Run should be installed on target devices.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$ServiceName`: Service to inspect or repair.
- `$AcceptableStartModes`: Startup modes allowed by detection.
- `$RequireRunning`: Whether detection requires the service to be running.
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

- Detection exits `0` when Office Click-to-Run service state matches expectations.
- Detection exits `1` when the service is missing, stopped, disabled, or otherwise noncompliant.
- Remediation exits `0` when startup type and service state validate successfully.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Office-ClickToRun-Service-Running`.

## Troubleshooting

- If the service is missing, confirm Microsoft 365 Apps or Office Click-to-Run is installed.
- If the service will not start, review Office Click-to-Run logs and application event logs.
- If policy disables the service again, check GPO, security baseline, or hardening tools.
- Review script logs and Intune Management Extension logs together.
