# Custom Compliance

Use this category for Intune custom compliance policies. A discovery script returns device settings as JSON, and a JSON rules file defines the compliant values.

## Folder Standard

```text
Custom-Compliance/
`-- <Purpose-Category>/
    `-- <Script-Name>/
        |-- Discover.ps1
        |-- ComplianceRules.json
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

## Discovery Script Rules

- Return one compressed JSON object.
- Do not write extra output to STDOUT.
- Keep script output under the Intune custom compliance output limit.
- Return every property referenced by `ComplianceRules.json`.
- Use case-sensitive property names consistently.

## Compliance Rule Rules

- Put rules inside the top-level `Rules` array.
- Match each `SettingName` to a property returned by `Discover.ps1`.
- Use the correct `DataType` for each returned value.
- Include at least one `en_US` remediation string.

## Intune Settings

Recommended defaults:

| Setting | Recommendation |
| --- | --- |
| Run using logged-on credentials | No for device-level checks |
| Run script in 64-bit PowerShell host | Yes for BitLocker, registry, and system-level checks |
| Enforce script signature check | Match your organization's signing policy |

## Examples

| Folder | Purpose |
| --- | --- |
| `Compliance/Example-Check-BitLocker-Status` | Reports BitLocker protection and encryption percentage |

## Add a New Custom Compliance Package

1. Choose the correct purpose category.
2. Copy the nearest example or create a starter folder with `tools/New-IntuneScriptFolder.ps1`.
3. Rename output properties in `Discover.ps1`.
4. Update `ComplianceRules.json`.
5. Run the discovery script locally and confirm valid compressed JSON.
6. Test the compliance policy against a pilot group.
