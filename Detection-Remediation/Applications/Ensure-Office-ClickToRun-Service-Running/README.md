# Ensure Office ClickToRun Service Running

## Summary

Detects and repairs Microsoft Office Click-to-Run service state. This helps with Office update, repair, and launch issues where `ClickToRunSvc` is disabled or stopped.

**Repository status:** `PilotReady`. The package passed repository contract review and is ready for a controlled nonproduction pilot. It is not yet `Validated` for broad deployment.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Run in 64-bit PowerShell.
- Microsoft 365 Apps or another Office Click-to-Run product must be installed on every target device.
- Use an Intune assignment filter or group that excludes devices without `ClickToRunSvc`. A missing service is an honest failure, not a compliant or remediated state.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$ServiceName`: Service to inspect or repair.
- `$ExpectedStartMode`: Exact WMI startup mode required by both scripts. Default is `Auto`.
- `$RequireRunning`: Whether detection requires the service to be running.
- `$StartupType`: Startup type remediation applies.
- `$ValidationDelaySeconds`: Delay before post-remediation validation.

Keep `$ExpectedStartMode`, `$RequireRunning`, and the corresponding `$StartupType` action aligned. The shipped state definition is `Auto` and `Running`.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` only when `ClickToRunSvc` is `Auto` and `Running`.
- Detection exits `1` when the service is missing or either expected value does not match.
- Remediation sets the startup type to `Automatic`, starts the service when required, and exits `0` only when the same `Auto`/`Running` state validates successfully.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Office-ClickToRun-Service-Running`.

## Pilot Validation

Use a disposable or nonproduction device that has an Office Click-to-Run installation, and test in the same System/64-bit context configured in Intune.

1. Record the device OS build, Office product/version, and original `ClickToRunSvc` startup mode and state.
2. Confirm the service is `Auto` and `Running`, then run `Detect.ps1`; expect exit `0`.
3. Close Office applications. On the pilot device only, set the service to `Manual` and stop it.
4. Run `Detect.ps1`; expect exit `1` and a clear noncompliant message.
5. Run `Remediate.ps1`; expect exit `0` only after startup mode is `Auto` and state is `Running`.
6. Run `Detect.ps1` again; expect exit `0`, then launch an Office application and confirm normal behavior.
7. Review both package logs and the Intune Management Extension log, then restore the original service configuration if required by the pilot plan.

Do not change this package to `Validated` until the result is documented using the evidence fields in `docs/Trusted-Remediation-Pilot.md`.

## Rollback

Restore the recorded original `ClickToRunSvc` startup mode and state. If Office does not operate normally after the pilot, remove the assignment and use the organization-approved Microsoft 365 Apps repair process.

## Troubleshooting

- If the service is missing, confirm Microsoft 365 Apps or Office Click-to-Run is installed.
- If the service will not start, review Office Click-to-Run logs and application event logs.
- If policy disables the service again, check GPO, security baseline, or hardening tools.
- Review script logs and Intune Management Extension logs together.

## Microsoft References

- [Use Remediations to detect and fix support issues](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
- [Application was unable to start correctly when accessing Microsoft 365 apps](https://learn.microsoft.com/en-us/previous-versions/troubleshoot/microsoft-365/microsoft-365-apps/office-suite-problems/error-when-starting-apps) documents the `ClickToRunSvc` service and a supported stop/start troubleshooting sequence.
