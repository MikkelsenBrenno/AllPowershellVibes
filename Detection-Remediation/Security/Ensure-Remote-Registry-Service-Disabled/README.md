# Ensure-Remote-Registry-Service-Disabled

## Summary

Detects and optionally disables the Remote Registry service. This is a focused hardening package for environments where remote registry access should not be available.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Use on Windows client devices.
- Confirm no approved management tooling depends on Remote Registry.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$ServiceName`: Remote Registry service name.
- `$ExpectedStartMode`: Startup mode expected by detection.
- `$RequireStopped`: Require the service state to be `Stopped`.
- `$StartupType`: Startup type applied by remediation.
- `$StopServiceAfterChange`: Stop the service during remediation.
- `$ApplyPolicy`: Set to `$true` in `Remediate.ps1` after pilot testing.
- `$ExitZeroInReportingOnlyMode`: Set to `$true` only when report-only remediation should appear successful.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when Remote Registry startup mode and state match policy.
- Detection exits `1` when the service is missing, enabled, or running while `$RequireStopped` is enabled.
- Remediation exits `1` in report-only mode by default.
- Remediation exits `0` after `$ApplyPolicy` is enabled and the service is disabled.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Remote-Registry-Service-Disabled`.

## Troubleshooting

- If remediation keeps reporting only, verify `$ApplyPolicy` is set to `$true`.
- If the service restarts or re-enables, review GPO, Settings Catalog, hardening baselines, or management tools.
- If the service is missing, confirm the target OS supports it.
- Review script logs and Intune Management Extension logs together.
