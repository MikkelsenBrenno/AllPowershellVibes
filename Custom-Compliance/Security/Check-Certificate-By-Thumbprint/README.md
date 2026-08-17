# Check Certificate By Thumbprint

## Summary

This custom compliance package checks whether a specific certificate thumbprint exists in one of the configured certificate stores.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ExpectedThumbprint` | Certificate thumbprint to search for. | Placeholder thumbprint |
| `$CertificateStorePaths` | Certificate stores to search. | LocalMachine Root, CA, and My |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended for LocalMachine certificate stores.

## Customization

Replace `$ExpectedThumbprint` with the real certificate thumbprint and remove stores that are not relevant.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No for LocalMachine stores |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices where the certificate should already exist.

## Expected Results

Compliant devices return `CertificateThumbprintPresent` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Certificate-By-Thumbprint`.
- Confirm the thumbprint has no hidden spaces.
- Confirm the certificate is in one of the configured stores.

## Common Failures

- The placeholder thumbprint was not replaced.
- The certificate exists in CurrentUser but the script checks LocalMachine.
