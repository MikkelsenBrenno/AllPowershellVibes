# Install Compliance Baseline Marker

## Summary

This Win32 packaged script installs, detects, and removes a local registry marker for a baseline, migration, or compliance rollout state.

## Files

- `Install.ps1` - Writes the registry marker.
- `Detect.ps1` - Detects the marker name and version.
- `Uninstall.ps1` - Removes the configured marker key.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$MarkerRegistryPath` | Registry key used for the marker. | `HKLM:\SOFTWARE\Microsoft\IntuneScriptLibrary\Win32ComplianceMarker` |
| `$BaselineName` | Baseline or rollout name written during install. | `Example Baseline` |
| `$BaselineVersion` | Version written during install. | `1.0.0` |
| `$ExpectedBaselineName` | Name expected by detection. | `Example Baseline` |
| `$ExpectedBaselineVersion` | Version expected by detection. | `1.0.0` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- System install behavior when writing HKLM.

## Customization

Replace the baseline name, version, and registry path with tenant-specific values. Keep install and detection values aligned.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\Compliance\Install-Compliance-Baseline-Marker" -s "Install.ps1" -o ".\PackageOutput"
```

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Install command | `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1` |
| Uninstall command | `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1` |
| Install behavior | System |
| Detection rule | Custom detection script |
| Detection script | `Detect.ps1` |
| Run detection as 32-bit on 64-bit clients | No |

## Intune App Commands

Use the install and uninstall commands shown above.

## Exit Codes

- Install `0` - Marker was written and validated.
- Install `1` - Marker install failed.
- Detection `0` with STDOUT - Marker is detected.
- Detection `1` - Marker is missing or different.
- Uninstall `0` - Marker is absent.
- Uninstall `1` - Marker removal failed.

## Expected Results

The configured registry marker exists and matches the expected baseline name and version.

## Troubleshooting

- Confirm install and detection use the same baseline values.
- Confirm the app runs as System when writing HKLM.
- Review script logs and Intune Management Extension logs together.
