# Ensure NetBIOS Over TCPIP Disabled

## Summary

Detects IP-enabled adapters where NetBIOS over TCP/IP is not disabled and can remediate them. The remediation is report-only by default because network adapter targeting should be tested carefully.

## Prerequisites

Run in the system context with 64-bit PowerShell. Confirm that disabling NetBIOS over TCP/IP is appropriate for your network before enabling remediation.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$AdapterDescriptionPatterns`: Adapter descriptions to include.
- `$ExpectedTcpipNetbiosOptions`: Detection target, normally `2` for disabled.
- `$ApplyNetBiosChange`: Set to `$true` in `Remediate.ps1` after pilot testing.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Use 64-bit PowerShell and run as system.

## Expected Results

Detection exits 0 when matching adapters are disabled for NetBIOS over TCP/IP and exits 1 when any matching adapter differs.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-NetBIOS-Over-TCPIP-Disabled`. If the wrong adapters are targeted, narrow `$AdapterDescriptionPatterns`.
