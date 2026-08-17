# Check Certificates Expiring Soon

## Summary

This custom compliance package checks a certificate store for certificates that expire within a configurable number of days.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$CertificateStorePath` | Certificate store to inspect. | `Cert:\LocalMachine\My` |
| `$ExpireWithinDays` | Expiration window in days. | `30` |
| `$SubjectPattern` | Optional subject filter. | `*` |
| `$IncludeExpiredCertificates` | Count already expired certificates. | `$true` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Custom compliance policy support.
- System context recommended for LocalMachine certificate stores.

## Customization

Change `$CertificateStorePath` and `$SubjectPattern` to target the certificate location your organization cares about.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No for LocalMachine stores |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to a pilot group and compare reported certificates with the local certificate console.

## Expected Results

Compliant devices return `NoCertificatesExpiringSoon` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Certificates-Expiring-Soon`.
- Confirm the store path exists.
- Confirm the subject filter is not too broad or too narrow.

## Common Failures

- The script runs as a user while checking a LocalMachine store.
- The certificate subject pattern does not match the expected certificate.
