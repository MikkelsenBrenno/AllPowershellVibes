# Check-Battery-Log-Snapshot

## Summary

Discovers whether a device exposes readable battery telemetry for Intune custom compliance evaluation.

The discovery script queries `Win32_Battery` and returns a compressed JSON snapshot. It does not generate a battery report or change device configuration.

## Prerequisites

- Windows PowerShell 5.1.
- Review the `CONFIGURATION` section before deployment.
- Devices without batteries are treated as compliant by default. Change `$TreatNoBatteryAsCompliant` if desktops should be reported differently.

## Customization

Editable values are kept near the top of the script. Review `$TreatNoBatteryAsCompliant` before assignment.

## Intune Settings

Deploy this package through the matching Intune workload. Use system context unless the README or script comments are changed for a user-context scenario.

## Expected Results

- The script exits `0` after returning compressed JSON for Intune custom compliance.
- `BatteryLogSnapshotCompliant` is `true` when no battery is present and `$TreatNoBatteryAsCompliant` is enabled.
- `BatteryLogSnapshotCompliant` is `true` when at least one battery is returned by `Win32_Battery`.
- The JSON also reports battery count, status codes, and estimated charge values for troubleshooting.
- Local logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs` when the running account can write there.

## Troubleshooting

- Check the script log folder named after this package.
- Confirm the device exposes `Win32_Battery`.
- On local non-admin tests, ProgramData logging may be unavailable even though Intune system context can write there.

## Source Credits

Repository-generated template content. No external GitHub source was copied for this package.
