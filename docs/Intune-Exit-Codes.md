# Intune Exit Codes

Intune uses exit codes differently depending on workload. Keep script output small and predictable.

## Detection And Remediation

Detection script:

| Exit code | Meaning |
| --- | --- |
| `0` | Device is compliant. Remediation does not run. |
| `1` | Device is noncompliant. Remediation should run. |

Remediation script:

| Exit code | Meaning |
| --- | --- |
| `0` | Remediation completed or final state is compliant. |
| `1` | Remediation failed or final state remains noncompliant. |

## Win32 App Detection

Custom detection script:

| Exit code | STDOUT | Meaning |
| --- | --- | --- |
| `0` | Any non-empty output | App or configuration is detected. |
| `0` | Empty output | Avoid this. Intune may not treat it as detected. |
| `1` | Any output | App or configuration is not detected. |

## Custom Compliance

Discovery scripts should:

- Exit `0` after returning JSON.
- Return only compressed JSON to STDOUT.
- Put troubleshooting detail in log files, not STDOUT.

The JSON rule file decides whether the returned values are compliant.

## Platform Scripts

Platform scripts generally use:

| Exit code | Meaning |
| --- | --- |
| `0` | Script completed successfully. |
| `1` | Script failed or intentionally refused to run because customization is incomplete. |

## Practical Rules

- Use `Write-Output` only for short Intune-facing status.
- Write detailed troubleshooting to the script log.
- Validate final state before exiting `0`.
- Use clear report-only behavior when a script is not meant to change anything yet.
