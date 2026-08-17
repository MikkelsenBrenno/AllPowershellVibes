# Ensure-BITS-Service-Available

## Summary

Detects and remediates devices where Background Intelligent Transfer Service is disabled. BITS is commonly involved in Windows Update and background download behavior, so this gives technicians a focused health repair package.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Use on Windows client devices.
- Pilot before broad deployment, especially if another baseline manages service startup state.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$ServiceName`: BITS service name. Default is `BITS`.
- `$AllowedStartModes`: Startup modes accepted by detection.
- `$RequireRunning`: Set to `$true` only if your policy requires the service to be running during detection.
- `$StartupType`: Startup type applied by remediation.
- `$StartServiceAfterChange`: Set to `$true` to start the service after remediation.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when the service exists and startup mode is allowed.
- Detection exits `1` when the service is missing, disabled, or stopped while `$RequireRunning` is enabled.
- Remediation exits `0` after the startup mode is restored.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-BITS-Service-Available`.

## Troubleshooting

- If remediation fails, verify the BITS service exists on the device.
- If the service keeps reverting to disabled, check security baseline or hardening policy assignment.
- If `$RequireRunning` is enabled, remember that BITS may stop when idle.
- Review Intune Management Extension logs and the script log together.
