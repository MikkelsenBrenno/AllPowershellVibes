# Pull Request

## Summary

Describe what changed and why.

## Script Category

- [ ] Detection and Remediation
- [ ] Custom Compliance
- [ ] Intune Platform Script
- [ ] Win32 Packaged Script
- [ ] Documentation only
- [ ] Repository tooling

## Purpose Category

- [ ] Security
- [ ] Compliance
- [ ] Device-Configuration
- [ ] Applications
- [ ] Maintenance
- [ ] Endpoint-Health
- [ ] Networking
- [ ] User-Experience
- [ ] Inventory-Reporting
- [ ] Windows-Updates
- [ ] Not applicable

## Checklist

- [ ] Scripts use PowerShell 5.1-compatible syntax.
- [ ] Customization values are in a `CONFIGURATION` section.
- [ ] Scripts include logging and error handling.
- [ ] Exit codes match the Intune workload.
- [ ] README includes prerequisites, customization, deployment, expected results, and troubleshooting.
- [ ] No tenant-specific IDs, secrets, device names, or internal URLs are included.
- [ ] `tools\Test-Repository.ps1` passes locally.

## Testing

Describe how this was tested, including context and 32-bit or 64-bit PowerShell behavior.
