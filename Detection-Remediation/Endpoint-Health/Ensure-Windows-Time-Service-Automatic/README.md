# Ensure-Windows-Time-Service-Automatic

## Summary

Detects and remediates Windows Time service startup mode. This is useful when devices have time sync issues and you want a focused service-baseline remediation separate from full time resync repair.

**Repository status:** `NeedsReview`. Do not treat this package as part of the trusted pilot set. Microsoft documents different Windows Time behavior for domain-joined and workgroup devices, so forcing `Automatic` is not a universal Windows client baseline.

## Applicability Hold

Before this package can become `PilotReady`, its intended join state and time-source policy must be explicit and tested. Domain-joined devices normally synchronize through the AD DS hierarchy. Workgroup devices use trigger-start behavior and can legitimately have `W32Time` set to `Manual` and stopped between synchronization events. Targeting both with one `Automatic` rule can create misleading noncompliance without proving that time synchronization is unhealthy.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Do not assign while status is `NeedsReview`.
- Decide whether the intended scope is AD DS domain-joined, Microsoft Entra joined/workgroup, or another explicitly documented configuration.
- Confirm the authoritative time-source policy and any GPO, MDM, virtualization, or security baseline that manages Windows Time.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$ServiceName`: Windows Time service name. Default is `W32Time`.
- `$ExpectedStartMode`: WMI start mode expected by detection. Default is `Auto`.
- `$RequireRunning`: Shared state definition used by both scripts. Default is `$false`.
- `$StartupType`: Startup type applied by remediation.

The scripts now validate the same startup mode and optional running state, but that technical alignment does not resolve the assignment-applicability question.

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

## Pilot Validation

Blocked while this package is `NeedsReview`. Do not upload it as a trusted pilot. First redesign the package for one documented join-state/time-source scenario, then repeat contract review and add a scenario-specific rollback test.

## Microsoft References

- [Windows Time service tools and settings](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/Windows-Time-Service-Tools-and-Settings)
- [Windows Time service does not start on a workgroup computer](https://learn.microsoft.com/en-us/troubleshoot/windows-client/active-directory/w32time-not-start-on-workgroup)
- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
