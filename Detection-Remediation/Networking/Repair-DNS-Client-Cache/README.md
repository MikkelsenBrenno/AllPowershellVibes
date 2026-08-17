# Repair DNS Client Cache

## Summary

Detects DNS resolution failure for a configured hostname and clears the local DNS client cache during remediation.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm the configured hostname should resolve from the target network.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$HostnameToResolve`: Hostname used for detection and validation.
- `$DnsQueryType`: DNS record type to query.
- `$RegisterDnsAfterFlush`: Optionally runs `ipconfig /registerdns`.
- `$ValidationDelaySeconds`: Delay before post-remediation validation.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when DNS resolution succeeds.
- Detection exits `1` when DNS resolution fails.
- Remediation exits `0` when cache clearing is followed by successful resolution.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Repair-DNS-Client-Cache`.

## Troubleshooting

- Confirm DNS servers are reachable from the target network.
- If resolution still fails after cache clearing, review VPN, proxy, DNS suffix, and firewall rules.
- Set `$HostnameToResolve` to a tenant-relevant internal or Microsoft cloud hostname.
- Review script logs and Intune Management Extension logs together.
