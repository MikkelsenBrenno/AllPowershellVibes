# Detection and Remediation

Use this category for Intune Remediations packages. Each package contains a detection script and, when needed, a remediation script.

This is the best fit for Defender Secure Score style fixes where a device setting must be checked repeatedly and corrected when it drifts.

## Folder Standard

```text
Detection-Remediation/
`-- <Purpose-Category>/
    `-- <Script-Name>/
        |-- Detect.ps1
        |-- Remediate.ps1
        `-- README.md
```

## Purpose Categories

- `Security`
- `Compliance`
- `Device-Configuration`
- `Applications`
- `Maintenance`
- `Endpoint-Health`
- `Networking`
- `User-Experience`
- `Inventory-Reporting`
- `Windows-Updates`

## Detection Script Rules

- Read current state.
- Do not make changes.
- Exit `0` when compliant.
- Exit `1` when remediation should run.
- Keep STDOUT short and useful for Intune reporting.

## Remediation Script Rules

- Make the smallest required change.
- Validate the result after changing it.
- Exit `0` only when validation succeeds.
- Exit `1` if the issue remains.

## Intune Settings

Recommended defaults:

| Setting | Recommendation |
| --- | --- |
| Run using logged-on credentials | No, unless changing user profile or HKCU settings |
| Run script in 64-bit PowerShell | Yes for registry and system-level checks |
| Enforce script signature check | Match your organization's signing policy |

## Examples

| Folder | Purpose |
| --- | --- |
| `Maintenance/Example-Ensure-Service-Running` | Checks and starts a Windows service |

## Add a New Detection and Remediation Package

1. Choose the correct purpose category.
2. Copy the nearest example or create a starter folder with `tools/New-IntuneScriptFolder.ps1`.
3. Rename the folder using the pattern in `docs/Naming-Conventions.md`.
4. Edit `Detect.ps1` first and keep it read-only.
5. Edit `Remediate.ps1` and validate the final state.
6. Update the folder README.
7. Test detection-only behavior before testing remediation.
