# Install VPN Profile Template

## Summary

This Win32 packaged script installs, detects, and removes a configurable Windows VPN profile. It is intended as a starting point for teams that need more control than a simple profile example.

## Files

- `Install.ps1` - Creates the VPN profile.
- `Detect.ps1` - Detects the VPN profile and expected server address.
- `Uninstall.ps1` - Removes the configured VPN profile.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$VpnName` | VPN profile name. | `Example VPN Profile` |
| `$ServerAddress` | VPN server address. | `vpn.contoso.example` |
| `$ExpectedServerAddress` | Server address expected by detection. | `vpn.contoso.example` |
| `$TunnelType` | VPN tunnel type passed to `Add-VpnConnection`. | `Automatic` |
| `$AuthenticationMethod` | VPN authentication method. | `Eap` |
| `$AllUserConnection` | Creates/removes an all-user profile. | `$true` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- VPN settings approved and tested for your organization.

## Customization

Replace `$ServerAddress` before deployment. Add EAP XML, routes, DNS suffix, split tunneling, or authentication options as needed for your environment.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\Networking\Install-VPN-Profile-Template" -s "Install.ps1" -o ".\PackageOutput"
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

- Install `0` - VPN profile was created.
- Install `1` - VPN profile install failed.
- Detection `0` with STDOUT - VPN profile is detected.
- Detection `1` - VPN profile is missing or points to a different server.
- Uninstall `0` - VPN profile is absent.
- Uninstall `1` - VPN profile removal failed.

## Expected Results

The configured VPN profile exists and points to the expected server address.

## Troubleshooting

- Replace the placeholder server address before deployment.
- Confirm VPN cmdlets are available on the target device.
- Confirm install behavior matches `$AllUserConnection`.
- Review script logs and Intune Management Extension logs together.
