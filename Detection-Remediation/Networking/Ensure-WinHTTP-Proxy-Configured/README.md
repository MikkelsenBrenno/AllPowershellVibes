# Ensure WinHTTP Proxy Configured

## Summary

Detects and optionally configures WinHTTP proxy settings. The remediation starts in report-only mode so administrators can confirm direct access, proxy server, and bypass list values before enforcement.

## Prerequisites

- Deploy as an Intune Remediations package.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm whether device services require direct access or a tenant proxy.

## Customization

Edit the CONFIGURATION section near the top of each script:

- `$ExpectedDirectAccess`: Detection passes when WinHTTP reports direct access.
- `$ExpectedWinHttpProxyContains`: Text expected in `netsh winhttp show proxy` output.
- `$SetDirectAccess`: Remediation resets WinHTTP proxy when `$true`.
- `$WinHttpProxyServer`: Proxy server used when `$SetDirectAccess` is `$false`.
- `$WinHttpBypassList`: Optional bypass list used when setting proxy.
- `$ApplyProxy`: Set to `$true` in `Remediate.ps1` after pilot testing.
- `$ExitZeroInReportingOnlyMode`: Set to `$true` only when report-only remediation should appear successful.

## Intune Settings

- Detection script: `Detect.ps1`
- Remediation script: `Remediate.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Detection exits `0` when WinHTTP proxy matches the expected configuration.
- Detection exits `1` when WinHTTP proxy is missing or different.
- Remediation exits `1` in report-only mode by default.
- Remediation exits `0` after `$ApplyProxy` is enabled and validation succeeds.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-WinHTTP-Proxy-Configured`.

## Troubleshooting

- If remediation keeps reporting only, verify `$ApplyProxy` is set to `$true`.
- If updates or services fail after changing proxy, validate bypass list and authentication requirements.
- Confirm GPO, proxy scripts, or security agents are not overwriting WinHTTP configuration.
- Review script logs and Intune Management Extension logs together.
