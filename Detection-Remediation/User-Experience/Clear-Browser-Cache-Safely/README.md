# Clear-Browser-Cache-Safely

## Summary

Detects and optionally clears old Microsoft Edge and Google Chrome cache files under local user profiles. This is useful when technicians need a safe, easy-to-customize remediation for disk cleanup or browser troubleshooting.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Test with pilot devices before enabling deletion.
- Close browser sessions during pilot testing if you want to reduce locked-file warnings.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$ExcludedProfileNames`: Profile folders that should never be scanned.
- `$MinimumCacheItemAgeDays`: Minimum age before a cache file becomes a candidate.
- `$BrowserCacheRelativePaths`: Browser cache paths to scan.
- `$DeleteCacheItems`: Set to `$true` in `Remediate.ps1` only after pilot testing.
- `$ExitZeroInReportingOnlyMode`: Set to `$true` only when you want report-only remediation to appear successful.

Local user profiles are discovered through `Win32_UserProfile`, with the system drive's `Users` folder used as a fallback.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`
- Schedule: Start with a pilot group and a conservative schedule.

## Expected Results

- Detection exits `0` when no old browser cache files are found.
- Detection exits `1` when old browser cache files are found.
- Remediation exits `1` in report-only mode by default when candidates exist.
- Remediation rescans and exits `0` only when no matching files remain and no deletion failed.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Clear-Browser-Cache-Safely`.

## Troubleshooting

- If remediation keeps reporting candidates, verify `$DeleteCacheItems` is set to `$true`.
- If files fail to delete, check whether the browser is running or files are locked.
- If no candidates are found, verify the browser profile path and cache relative paths match your environment.
- Review the remediation log for exact file counts and failed removals.
