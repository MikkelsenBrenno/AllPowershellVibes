# Ensure-Delivery-Optimization-Service-Enabled

## Summary

Detects and remediates devices where the Delivery Optimization service is disabled. This helps preserve Windows Update, Microsoft Store, and content delivery behavior on managed endpoints.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Use on Windows client devices that include the Delivery Optimization service.
- Pilot before broad deployment, especially if other tooling manages service startup state.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$ServiceName`: Delivery Optimization service name. Default is `DoSvc`.
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
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Delivery-Optimization-Service-Enabled`.

## Troubleshooting

- If remediation fails, verify the device supports the Delivery Optimization service.
- If the service keeps reverting to disabled, check baseline, security, or hardening policies.
- If `$RequireRunning` is enabled, remember that trigger-start services may not always remain running.
- Review Intune Management Extension logs and the script log together.
