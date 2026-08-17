# Install-Credential-Provider-Package

## Summary

Packages Credential Provider configuration or evidence as a reusable Win32 script deployment.

## Prerequisites

- Windows PowerShell 5.1.
- Review the `CONFIGURATION` section before deployment.
- Replace values such as `contoso.com`, `ExampleVpn`, `PrinterName`, and marker paths with organization-approved values.

## Customization

Editable values are kept near the top of each script. Start with the managed item name, expected state, marker path, registry path, service name, certificate subject, printer name, or support bundle path as applicable.

## Intune Deployment

Deploy this package through the matching Intune workload. Use system context unless the README or script comments are changed for a user-context scenario.

## Expected Results

- Compliant or detected state exits `0`.
- Noncompliant, missing, stale, or not detected state exits `1`.
- Local logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs` when the running account can write there.

## Troubleshooting

- Check the script log folder named after this package.
- Confirm the configured paths, marker values, and expected values match the target environment.
- On local non-admin tests, ProgramData logging may be unavailable even though Intune system context can write there.

## Source Credits

Original repository implementation inspired by public Intune remediation, reporting, and Win32 packaging examples. No external source code was copied.

- [Microsoft Intune Remediations deployment documentation](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
- [JayRHa/EndpointAnalyticsRemediationScripts](https://github.com/JayRHa/EndpointAnalyticsRemediationScripts)
- [nickj76/Intune-Proactive-Remediations](https://github.com/nickj76/Intune-Proactive-Remediations)
- [MSEndpointMgr/IntuneWin32App](https://github.com/MSEndpointMgr/IntuneWin32App)
- [microsoft/intune-tenant-doc](https://github.com/microsoft/intune-tenant-doc)
