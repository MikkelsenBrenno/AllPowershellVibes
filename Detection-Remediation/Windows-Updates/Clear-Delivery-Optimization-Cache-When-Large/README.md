# Clear Delivery Optimization Cache When Large

## Summary

Detects large Delivery Optimization cache usage and clears it through the supported PowerShell cmdlet when enabled.

## Files

- `Detect.ps1` - Checks the current state.
- `Remediate.ps1` - Fixes or reports the issue when detection exits `1`.

## What To Change First

Open both scripts and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `$MaximumCacheSizeMB` | Cache size threshold before remediation is needed. | `5120` |
| `$ClearDeliveryOptimizationCache` | Safety toggle that enables cache cleanup. | `$true` |
| `$ValidationDelaySeconds` | Wait time before remediation validation. | `5` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context.
- Delivery Optimization PowerShell cmdlets available on target devices.

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

- Detection exits `0` when Delivery Optimization cache size is under the configured threshold.
- Detection exits `1` when the scan limit prevents a trustworthy size result.
- Remediation clears the cache with `Delete-DeliveryOptimizationCache` when available.
- Report-only execution remains noncompliant by default.
- Final validation confirms cache size is under the threshold and the scan was complete.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Clear-Delivery-Optimization-Cache-When-Large`.
- Confirm the device supports `Delete-DeliveryOptimizationCache`.
- Verify Delivery Optimization service health if cache cleanup fails.

## Source Inspiration

Original implementation for this repository. Topic inspiration comes from disk cleanup and Windows Update maintenance examples in [JayRHa/EndpointAnalyticsRemediationScripts](https://github.com/JayRHa/EndpointAnalyticsRemediationScripts), [MSEndpointMgr/ProactiveRemediations](https://github.com/MSEndpointMgr/ProactiveRemediations), and Microsoft Windows Update for Business troubleshooting patterns.

