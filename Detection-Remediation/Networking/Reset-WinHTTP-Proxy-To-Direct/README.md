# Reset WinHTTP Proxy To Direct

## Summary

Detects WinHTTP proxy settings that are not direct access and optionally resets them for environments that do not require device-level proxy configuration.

## Files

- `Detect.ps1` - Checks the current state.
- `Remediate.ps1` - Fixes or reports the issue when detection exits `1`.

## What To Change First

Open both scripts and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `$DirectAccessIndicators` | Text fragments that indicate WinHTTP direct access in `netsh` output. | `Direct access`, `no proxy server` |
| `$ResetWinHttpProxy` | Safety toggle to actually reset WinHTTP proxy. | `$true` |
| `$ValidationDelaySeconds` | Wait time before remediation validation. | `2` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context.
- Confirm the tenant does not require a device-level WinHTTP proxy.

## Customization

Update the `CONFIGURATION` section in both scripts before deployment. Keep tenant-specific values, paths, profile names, and safety toggles near the top so technicians can review them immediately.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

1. Go to Intune admin center.
2. Open **Devices > Manage devices > Scripts and remediations**.
3. Create a script package.
4. Upload `Detect.ps1` as the detection script.
5. Upload `Remediate.ps1` as the remediation script.
6. Choose the settings above.
7. Assign to a small pilot group first.

## Expected Results

- Detection exits `0` when WinHTTP proxy output indicates direct access.
- Remediation runs `netsh winhttp reset proxy` when `$ResetWinHttpProxy` is `$true`.
- Validation confirms the final WinHTTP proxy output.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Reset-WinHTTP-Proxy-To-Direct`.
- If the device requires a proxy, use `Ensure-WinHTTP-Proxy-Configured` instead.
- Localized Windows builds can change `netsh` output text; update `$DirectAccessIndicators` as needed.

## Source Inspiration

Original implementation for this repository. Topic inspiration comes from public proxy remediation examples such as [JayRHa/EndpointAnalyticsRemediationScripts](https://github.com/JayRHa/EndpointAnalyticsRemediationScripts) and general Intune remediation patterns.

