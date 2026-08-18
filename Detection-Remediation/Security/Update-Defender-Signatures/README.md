# Update-Defender-Signatures

## Summary

Detects stale Microsoft Defender antivirus signatures and optionally runs `Update-MpSignature`. The remediation starts in report-only mode so administrators can confirm network access and update source behavior before enabling enforcement.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Run in 64-bit PowerShell.
- Microsoft Defender Antivirus PowerShell cmdlets must be available.
- Devices must have access to the configured Defender signature update source.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$MaximumSignatureAgeDays`: Maximum allowed signature age before remediation is triggered.
- `$UpdateSource`: Optional source passed to `Update-MpSignature`.
- `$ApplyUpdate`: Set to `$true` in `Remediate.ps1` after pilot testing.
- `$ValidationAttempts`: Number of direct status readbacks after the update command.
- `$ValidationDelaySeconds`: Delay between direct status readbacks.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when Defender signatures are within the configured freshness window.
- Detection exits `1` when signatures are stale or Defender status is unavailable.
- Remediation exits `1` in report-only mode by default.
- Remediation exits `0` after `$ApplyUpdate` is enabled and signature freshness validates successfully.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Update-Defender-Signatures`.

## Troubleshooting

- If remediation keeps reporting only, verify `$ApplyUpdate` is set to `$true`.
- If updates fail, confirm proxy, firewall, Delivery Optimization, and Microsoft Defender update source settings.
- If signature age remains stale after a successful update command, review Defender platform health and Windows Update logs.
- Review script logs and Intune Management Extension logs together.

## Pilot Validation

1. Confirm the tenant's Defender security-intelligence source order and network path on a small pilot group.
2. Deploy with `$ApplyUpdate = $false`; stale or unavailable status must cause remediation to exit `1` without requesting an update.
3. Set `$ApplyUpdate = $true` and leave `$UpdateSource` empty unless the tenant intentionally requires one of the documented sources.
4. Compare `AntivirusSignatureLastUpdated` before and after remediation and verify the final timestamp is not in the future and is within `$MaximumSignatureAgeDays`.
5. Verify a fresh device exits `0` on the next detection run and review the package log for the final direct-state readback.

Microsoft references:

- [`Update-MpSignature`](https://learn.microsoft.com/en-us/powershell/module/defender/update-mpsignature?view=windowsserver2025-ps)
- [`Get-MpComputerStatus`](https://learn.microsoft.com/en-us/powershell/module/defender/get-mpcomputerstatus?view=windowsserver2025-ps)
- [Manage Microsoft Defender Antivirus protection updates](https://learn.microsoft.com/en-us/defender-endpoint/manage-protection-updates-microsoft-defender-antivirus)
- [Intune Remediations](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
