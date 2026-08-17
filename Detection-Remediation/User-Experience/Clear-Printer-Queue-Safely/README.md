# Clear-Printer-Queue-Safely

## Summary

Detects and optionally clears stale Windows print spooler queue files. This is useful when devices repeatedly show stuck print jobs or technicians need a controlled remediation for local print queue cleanup.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Test with pilot devices before enabling queue clearing.
- Confirm users understand that clearing the queue removes pending print jobs.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$SpoolFolder`: Print spool folder to inspect.
- `$MinimumPrintJobAgeMinutes`: Minimum file age before a print job file is considered stale.
- `$PrintJobFilePatterns`: File patterns to detect and remove.
- `$ClearPrintQueue`: Set to `$true` in `Remediate.ps1` only after pilot testing.
- `$ExitZeroInReportingOnlyMode`: Set to `$true` only when report-only remediation should appear successful.
- `$RestartPrintSpooler`: Stop and restart the spooler while clearing files.
- `$SpoolerServiceName`: Print Spooler service name.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`
- Schedule: Start with a small pilot group.

## Expected Results

- Detection exits `0` when no stale print queue files are found.
- Detection exits `1` when stale print queue files are found.
- Remediation exits `1` in report-only mode by default when stale files exist.
- Remediation exits `0` after stale files are removed successfully.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Clear-Printer-Queue-Safely`.

## Troubleshooting

- If remediation keeps reporting stale files, verify `$ClearPrintQueue` is set to `$true`.
- If files fail to remove, confirm the Print Spooler service can be stopped.
- If users report missing print jobs, confirm the remediation was expected to clear pending jobs.
- Review the script log for removed file counts and failed removals.
