# <Custom Compliance Script Name>

## Summary

Describe the custom compliance setting discovered by the PowerShell script and evaluated by the JSON rule file.

## Files

- `Discover.ps1` - Returns compressed JSON to Intune.
- `ComplianceRules.json` - Defines the expected compliant values.

## What To Change First

Open `Discover.ps1` and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `<SettingName>` | `<What admins should change>` | `<Default>` |

Then open `ComplianceRules.json` and confirm each `SettingName` exactly matches a property returned by `Discover.ps1`.

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Custom compliance policy support for the target platform.
- PowerShell 5.1.
- Any local permissions required to query the setting.

## Customization

Update the `CONFIGURATION` section in `Discover.ps1` before deployment. That section should contain every value technicians are expected to change, such as paths, registry keys, WMI/CIM class names, expected values, and tenant labels.

Update `ComplianceRules.json` so each `SettingName` exactly matches the JSON property returned by `Discover.ps1`. Setting names are case-sensitive.

Keep custom values near the top of the script so admins can review them quickly without reading the full script body.

## JSON Output

Discovery scripts should return one compressed JSON object, for example:

```json
{"ExampleSetting":true}
```

Avoid writing extra text to STDOUT because Intune evaluates the script output as JSON.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run this script using the logged-on credentials | `<Yes or No>` |
| Enforce script signature check | `<Tenant policy>` |
| Run script in 64-bit PowerShell | `<Yes when using native HKLM or System32 paths>` |

## Intune Deployment

1. Go to Intune admin center.
2. Open **Endpoint security > Device compliance > Scripts**.
3. Add the discovery script.
4. Create or edit a compliance policy.
5. Add custom compliance settings.
6. Upload `ComplianceRules.json`.
7. Select the discovery script.
8. Assign to a pilot group.

## Expected Results

Describe the compliant and noncompliant states.

## What Success Looks Like

- `Discover.ps1` exits `0`.
- STDOUT contains one compressed JSON object only.
- Each JSON property has the data type expected by `ComplianceRules.json`.
- Compliance policy reports show the expected setting values.

## Troubleshooting

- Run `Discover.ps1` locally and confirm it returns valid compressed JSON.
- Confirm every JSON rule `SettingName` exists in the script output.
- Confirm data types match between script output and `ComplianceRules.json`.
- Review Intune compliance policy reports.

## Common Failures

- Extra text is written to STDOUT before or after the JSON object.
- A `SettingName` in `ComplianceRules.json` does not exactly match the script output.
- A boolean, integer, or string value is returned with the wrong data type.
- The script is running in user context but needs system/admin permissions.
