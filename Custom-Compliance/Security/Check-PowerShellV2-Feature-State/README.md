# Check-PowerShellV2-Feature-State

## Summary

Reports whether the PowerShell 2.0 optional feature is disabled. This gives technicians a clear security-hardening signal while still exposing the raw optional feature state.

## Prerequisites

- Deploy as an Intune custom compliance discovery script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm legacy application compatibility before enforcing PowerShell 2.0 disablement.

## Customization

Edit the CONFIGURATION section near the top of `Discover.ps1`:

- `$FeatureName`: Optional feature to inspect.
- `$ExpectedState`: Expected feature state. Default is `Disabled`.

Also update `ComplianceRules.json` if the expected state changes.

## Intune Settings

- Discovery script: `Discover.ps1`
- Rules file: `ComplianceRules.json`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Output is compressed JSON.
- `PowerShellV2FeatureCompliant` is `true` when the optional feature state matches policy.
- `FeatureState` shows the raw optional feature state.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-PowerShellV2-Feature-State`.

## Troubleshooting

- If the feature is missing, verify the device OS supports the optional feature name.
- If disabling fails later, review whether a reboot or servicing state is blocking feature changes.
- If compliance and script results disagree, verify the script expected state and rules file operand match.
- Use the matching remediation package only after compatibility testing.
