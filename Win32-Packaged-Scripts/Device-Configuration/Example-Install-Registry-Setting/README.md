# Example: Install Registry Setting

## Summary

This Win32 packaged script example installs a registry-based configuration marker under HKLM. It includes install, uninstall, and custom detection scripts.

The example is intentionally simple so administrators can replace the registry path and value with their own app or configuration state.

## Files

- `Install.ps1` - Creates the registry key and value.
- `Uninstall.ps1` - Removes the registry value and optionally removes the dedicated key.
- `Detect.ps1` - Detects the expected registry value for Intune.

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- System install behavior recommended.
- 64-bit PowerShell recommended for native HKLM registry access.

## Customization

Update the `CONFIGURATION` section in all three scripts.

| Setting | Description | Default |
| --- | --- | --- |
| `$RegistryPath` | Dedicated registry key to create and detect. | `HKLM:\SOFTWARE\IntuneScriptLibrary\ExampleInstallRegistrySetting` |
| `$ValueName` | Registry value name. | `Configured` |
| `$ValueData` | Registry value data written by install. | `Enabled` |
| `$ExpectedValueData` | Registry value data expected by detection. | `Enabled` |
| `$ValueType` | Registry value type. | `String` |
| `$RemoveRegistryKey` | Whether uninstall removes the full key. Keep `$true` only for dedicated keys. | `$true` |

## Package Creation

From the repository root, run:

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\Device-Configuration\Example-Install-Registry-Setting" -s "Install.ps1" -o ".\PackageOutput"
```

Upload the generated `.intunewin` file to Intune.

## Intune App Configuration

Program install command:

```text
%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1
```

Program uninstall command:

```text
%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

Install behavior:

```text
System
```

Device restart behavior:

```text
No specific action
```

Detection rules:

1. Choose **Use a custom detection script**.
2. Upload `Detect.ps1`.
3. Set **Run script as 32-bit process on 64-bit clients** to **No**.
4. Set signature enforcement according to your organization's signing policy.

## Expected Results

- Install exits `0` after the registry value is written and validated.
- Detection exits `0` and writes output when the registry value matches.
- Detection exits `1` when the key or value is missing or does not match.
- Uninstall exits `0` after the value and dedicated key are removed.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Example-Install-Registry-Setting\Install.log`, `Uninstall.log`, and `Detect.log`.
- Confirm install, uninstall, and detection all use the same registry path and value.
- Confirm the app is not running detection in 32-bit mode if you wrote to the 64-bit registry view.
- Review Intune Management Extension logs in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
