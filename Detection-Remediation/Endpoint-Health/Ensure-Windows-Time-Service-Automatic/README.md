# Ensure-Windows-Time-Service-Automatic

## Summary

Detects and remediates Windows Time service startup mode. This is useful when devices have time sync issues and you want a focused service-baseline remediation separate from full time resync repair.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Use on Windows client devices.
- Pilot before broad deployment if another baseline manages service startup state.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$ServiceName`: Windows Time service name. Default is `W32Time`.
- `$ExpectedStartMode`: WMI start mode expected by detection. Default is `Auto`.
- `$RequireRunning`: Set to `$true` if detection should require the service to be running.
- `$StartupType`: Startup type applied by remediation.
- `$StartServiceAfterChange`: Start the service after changing startup type.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when Windows Time startup mode matches the expected value.
- Detection exits `1` when the service is missing, disabled, or stopped while `$RequireRunning` is enabled.
- Remediation exits `0` after the startup mode is restored.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Windows-Time-Service-Automatic`.

## Troubleshooting

- If remediation fails, verify the Windows Time service exists.
- If startup mode keeps changing back, check GPO, MDM policy, or security baseline assignments.
- If time source is still wrong, use the existing Windows Time repair package.
- Review script logs and Intune Management Extension logs together.
