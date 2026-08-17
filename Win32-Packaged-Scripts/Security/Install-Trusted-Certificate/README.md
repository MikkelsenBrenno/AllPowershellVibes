# Install Trusted Certificate

## Summary

This Win32 packaged script example installs, detects, and removes a certificate in a configurable certificate store.

## Files

- `Install.ps1` - Imports a `.cer` file from the package folder.
- `Detect.ps1` - Detects the certificate by thumbprint.
- `Uninstall.ps1` - Removes the certificate by thumbprint.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$CertificateFileName` | Certificate file included in the package. | `TrustedRootExample.cer` |
| `$ExpectedThumbprint` | Certificate thumbprint used by detection and uninstall. | `PASTE_CERTIFICATE_THUMBPRINT_HERE` |
| `$CertificateStoreLocation` | Certificate store location. | `LocalMachine` |
| `$CertificateStoreName` | Certificate store name. | `Root` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- A real `.cer` file placed beside `Install.ps1`.
- System install behavior recommended for `LocalMachine` stores.

## Customization

Paste the certificate thumbprint into `Detect.ps1` and `Uninstall.ps1`. Include the certificate file in the package folder before packaging.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\Security\Install-Trusted-Certificate" -s "Install.ps1" -o ".\PackageOutput"
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

- Install `0` - Certificate imported and detected.
- Install `1` - Certificate import failed.
- Detection `0` with STDOUT - Certificate exists.
- Detection `1` - Certificate missing.
- Uninstall `0` - Certificate removed or already absent.
- Uninstall `1` - Certificate removal failed.

## Expected Results

The certificate exists in the configured store after install and is absent after uninstall.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Install-Trusted-Certificate`.
- Confirm the certificate file is included in the Win32 package.
- Confirm thumbprint spacing is not copied incorrectly.

## Common Failures

- Detection thumbprint is not customized.
- Certificate file is missing from the package source folder.
- Store location requires system context but the app is deployed as user.
