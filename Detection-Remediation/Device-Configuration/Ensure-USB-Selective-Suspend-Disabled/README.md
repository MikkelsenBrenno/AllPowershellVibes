# Ensure USB Selective Suspend Disabled

## Summary

Detects whether USB selective suspend is disabled on the active power scheme and can set the AC and DC values. This is useful for devices with USB peripherals, docks, smart-card readers, or other devices that misbehave after power saving.

## Prerequisites

Run in the system context with 64-bit PowerShell. Pilot on laptops and docking stations before enabling remediation.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$UsbSettingsSubgroupGuid`: Power settings subgroup GUID.
- `$UsbSelectiveSuspendSettingGuid`: USB selective suspend setting GUID.
- `$ExpectedAcValueIndex` and `$ExpectedDcValueIndex`: Detection target values.
- `$ApplyPowerCfgChange`: Set to `$true` in `Remediate.ps1` after pilot testing.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Run as system with 64-bit PowerShell.

## Expected Results

Detection exits 0 when AC and DC values match the expected disabled value. Remediation reports intended powercfg changes until `$ApplyPowerCfgChange` is enabled.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-USB-Selective-Suspend-Disabled`. If parsing fails, run `powercfg /query` manually and confirm the GUIDs are valid on the target OS.
