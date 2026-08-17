# Check-Firewall-Baseline-Marker

## Summary

Discovers Firewall Baseline Marker state for Intune custom compliance evaluation.

## Prerequisites

- Windows PowerShell 5.1.
- Review the `CONFIGURATION` section before deployment.
- Replace Contoso/example values with organization-approved values.

## Customization

Editable values are kept near the top of each script. Start with the managed item name, marker or registry path, expected value, and timeout or age settings where present.

## Intune Settings

Deploy this package through the matching Intune workload. Use system context unless the README or script comments are changed for a user-context scenario.

## Expected Results

- Compliant or detected state exits `0`.
- Noncompliant, missing, stale, or not detected state exits `1`.
- Local logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs` when the running account can write there.

## Troubleshooting

- Check the script log folder named after this package.
- Confirm the configured paths, registry values, and expected values match the target tenant.
- On local non-admin tests, ProgramData logging may be unavailable even though Intune system context can write there.

## Source Credits

Repository-generated template content. No external GitHub source was copied for this package.
