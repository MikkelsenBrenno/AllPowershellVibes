# Ensure Edge SmartScreen Enabled

## Summary

Detects and remediates Microsoft Edge SmartScreen policy values commonly used to reduce phishing, malicious site, and unwanted app exposure.

## Files

- `Detect.ps1` - Checks the current state.
- `Remediate.ps1` - Fixes or reports the issue when detection exits `1`.

## What To Change First

Open both scripts and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `$RegistryValues` | Edge policy registry values to enforce. | SmartScreen enabled and prompt override blocked |
| `$ValidationDelaySeconds` | Wait time before remediation validation. | `2` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Edge installed or policy-ready.
- PowerShell 5.1.
- System context.
- 64-bit PowerShell.

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

- Detection exits `0` when all configured Edge SmartScreen policy values match.
- Remediation creates missing policy keys and writes the configured values.
- Edge may need a policy refresh or restart before the browser UI reflects the setting.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Edge-SmartScreen-Enabled`.
- Open `edge://policy` on a test device to confirm Edge reads the policy.
- Check whether Settings Catalog, Administrative Templates, or another policy controls the same values.

## Source Inspiration

Original implementation for this repository. Topic inspiration comes from Microsoft Edge and Defender hardening examples in public Intune repositories such as [aaronparker/intune](https://github.com/aaronparker/intune) and Microsoft policy documentation in [MicrosoftDocs/memdocs](https://github.com/MicrosoftDocs/memdocs).

