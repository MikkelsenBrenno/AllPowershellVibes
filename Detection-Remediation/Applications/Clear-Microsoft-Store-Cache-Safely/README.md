# Clear Microsoft Store Cache Safely

## Summary

Detects when the current user's Microsoft Store cache exceeds a configured size and can clear selected cache folders. The remediation defaults to report-only mode so technicians can verify the paths first.

## Prerequisites

Run in the user context if you want to target the signed-in user's Store cache. Close Microsoft Store before cleanup during pilot testing.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$PackagesRoot`: User package folder root.
- `$StorePackageFolderPattern`: Store package folder pattern.
- `$CacheFolderRelativePaths`: Cache subfolders to measure or clear.
- `$MaximumCacheSizeMB`: Detection threshold.
- `$ApplyCacheCleanup`: Set to `$true` in `Remediate.ps1` after pilot testing.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Run using the logged-on user's credentials.

## Expected Results

Detection exits 0 when cache size is below the threshold and exits 1 when it is too large. Remediation remains noncompliant in report-only mode, then remeasures the cache and exits 0 only after the configured threshold is met.

## Troubleshooting

Check logs under `%LOCALAPPDATA%\Microsoft\IntuneScriptLibrary\Logs\Clear-Microsoft-Store-Cache-Safely`. If no paths are found, verify the package folder exists under the user's `%LOCALAPPDATA%\Packages` path.
