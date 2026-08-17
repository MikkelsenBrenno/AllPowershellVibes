# Reset Windows Update Components Safely

## Summary

Detects stale Windows Update scan state and optionally resets selected local Windows Update components. The remediation starts in report-only mode because cache reset actions should be piloted carefully.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm reset scope with your update management owner before enabling remediation.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$MaximumLastScanAgeDays`: Maximum age for last successful Windows Update scan.
- `$TreatUnavailableScanHistoryAsNonCompliant`: Whether missing scan history should trigger remediation.
- `$ServicesToRestart`: Services stopped and restarted during reset.
- `$CacheFoldersToRename`: Cache folders renamed during reset.
- `$ApplyReset`: Set to `$true` in `Remediate.ps1` after pilot testing.
- `$ExitZeroInReportingOnlyMode`: Set to `$true` only when report-only remediation should appear successful.
- `$ServiceStopTimeoutSeconds`: Timeout for service stop waits.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when Windows Update scan history is recent.
- Detection exits `1` when scan history is stale or unavailable.
- Remediation exits `1` in report-only mode by default.
- Remediation exits `0` after `$ApplyReset` is enabled and reset completes.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Reset-Windows-Update-Components-Safely`.

## Troubleshooting

- If remediation keeps reporting only, verify `$ApplyReset` is set to `$true`.
- If services do not stop, increase `$ServiceStopTimeoutSeconds` or inspect service dependencies.
- If update policy still blocks scans, review Intune update rings, feature update policies, GPO, and proxy settings.
- Review script logs and Intune Management Extension logs together.
