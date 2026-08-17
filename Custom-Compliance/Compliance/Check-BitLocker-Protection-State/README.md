# Check-BitLocker-Protection-State

## Summary

Reports whether selected drives have BitLocker protection enabled and are fully encrypted. The output includes raw mount point, protection status, volume status, and encryption percentage.

## Prerequisites

- Deploy as an Intune custom compliance discovery script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Verify recovery key escrow and encryption policy before enforcing.

## Customization

Edit the CONFIGURATION section near the top of `Discover.ps1`:

- `$MountPoints`: Drives to evaluate.
- `$ExpectedProtectionStatus`: Expected BitLocker protection status.
- `$ExpectedVolumeStatus`: Expected BitLocker volume status.

## Intune Settings

- Discovery script: `Discover.ps1`
- Rules file: `ComplianceRules.json`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Output is compressed JSON.
- `BitLockerProtectionCompliant` is `true` when all selected drives match policy.
- `Volumes` lists raw BitLocker values for each selected mount point.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-BitLocker-Protection-State`.

## Troubleshooting

- If the BitLocker cmdlet is unavailable, confirm the BitLocker module is installed.
- If protection is suspended, review why protection was paused before enforcing.
- If encryption percentage is below 100, wait for encryption to complete or investigate encryption errors.
- Compare discovery output with `manage-bde -status` during pilot testing.
