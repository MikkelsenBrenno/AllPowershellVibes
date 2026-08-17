# Install Windows Update Policy Template

## Summary

This Win32 packaged script installs, detects, and removes configurable Windows Update target release policy registry values.

## Files

- `Install.ps1` - Writes Windows Update policy values.
- `Detect.ps1` - Detects the expected Windows Update policy values.
- `Uninstall.ps1` - Removes only the configured policy values.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$WindowsUpdatePolicyPath` | Registry path used for Windows Update policy. | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` |
| `$TargetReleaseVersionInfo` | Target release version written during install. | `REPLACE_WITH_TARGET_VERSION` |
| `$ExpectedTargetReleaseVersionInfo` | Target release version expected by detection. | `REPLACE_WITH_TARGET_VERSION` |
| `$ProductVersion` | Product version written during install. | `Windows 11` |
| `$ExpectedProductVersion` | Product version expected by detection. | `Windows 11` |
| `$ValueNamesToRemove` | Values removed during uninstall. | Target release values |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- System install behavior when writing HKLM.

## Customization

Replace `$TargetReleaseVersionInfo` and `$ExpectedTargetReleaseVersionInfo` before deployment. Keep install and detection values aligned.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\Windows-Updates\Install-Windows-Update-Policy-Template" -s "Install.ps1" -o ".\PackageOutput"
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

- Install `0` - Policy values were written and validated.
- Install `1` - Policy install failed.
- Detection `0` with STDOUT - Policy values are detected.
- Detection `1` - Policy values are missing or different.
- Uninstall `0` - Configured policy values are absent.
- Uninstall `1` - Policy removal failed.

## Expected Results

The configured Windows Update policy values exist and match the expected target release.

## Troubleshooting

- Replace the target release placeholder before packaging.
- Confirm another policy channel is not overwriting Windows Update values.
- Review script logs and Intune Management Extension logs together.
