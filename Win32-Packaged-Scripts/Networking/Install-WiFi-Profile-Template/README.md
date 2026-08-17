# Install WiFi Profile Template

## Summary

This Win32 packaged script installs, detects, and removes a Wi-Fi profile from an XML payload using `netsh wlan`.

## Files

- `WiFiProfile.xml` - Example Wi-Fi profile XML payload.
- `Install.ps1` - Imports the Wi-Fi profile and validates it.
- `Detect.ps1` - Detects the Wi-Fi profile by name.
- `Uninstall.ps1` - Removes the configured Wi-Fi profile.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$WiFiProfileXmlFileName` | XML file imported by install. | `WiFiProfile.xml` |
| `$WiFiProfileName` | Wi-Fi profile name expected by install and detection. | `Contoso WiFi` |
| `$ProfileScope` | Profile scope passed to netsh. | `all` |
| `WiFiProfile.xml` | Replace SSID, authentication, encryption, and passphrase values. | Placeholder profile |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- WLAN profile support available on the target device.
- Wi-Fi profile XML reviewed and approved before packaging.

## Customization

Replace the SSID and security values in `WiFiProfile.xml`. Never leave the placeholder passphrase in a deployed package.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\Networking\Install-WiFi-Profile-Template" -s "Install.ps1" -o ".\PackageOutput"
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

- Install `0` - Wi-Fi profile was imported and detected.
- Install `1` - Wi-Fi profile import failed.
- Detection `0` with STDOUT - Wi-Fi profile is detected.
- Detection `1` - Wi-Fi profile is missing.
- Uninstall `0` - Removal was requested.
- Uninstall `1` - Removal failed.

## Expected Results

The configured Wi-Fi profile exists on the device and appears in `netsh wlan show profiles`.

## Troubleshooting

- Replace the passphrase placeholder in `WiFiProfile.xml` before packaging.
- Confirm the profile name in the XML matches `$WiFiProfileName`.
- Confirm the device has WLAN components installed.
- Review script logs and Intune Management Extension logs together.
