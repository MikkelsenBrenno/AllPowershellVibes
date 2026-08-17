# Ensure TLS12 For NETFramework

## Summary

Detects and optionally configures .NET Framework strong crypto and system default TLS registry values. This package is useful for older applications and automation that still depend on .NET Framework TLS defaults.

## Prerequisites

Run in the system context with 64-bit PowerShell. Pilot before enabling remediation because legacy applications may have old TLS assumptions.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$RegistryTargets`: .NET Framework registry paths and value names.
- `$ExpectedValue` or `$TargetValue`: Desired DWORD value.
- `$ApplyRegistryChanges`: Set to `$true` in `Remediate.ps1` after pilot testing.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Use 64-bit PowerShell and run as system.

## Expected Results

Detection exits 0 when all configured registry values equal the expected value. Remediation defaults to report-only mode until `$ApplyRegistryChanges` is enabled.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-TLS12-For-NETFramework`. If applications still fail TLS negotiation, also inspect SCHANNEL protocol policy and application-specific TLS settings.
