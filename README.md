# AllPowershellVibes

> AI-generated experimental PowerShell and Intune script library, made for fun, learning, and exploration. Review, customize, and test everything carefully before using it in any real environment.

A reusable Microsoft Intune PowerShell script library for IT administrators who want scripts they can download, customize, test, and deploy in their own environments.

The repository is organized around the most common Intune script delivery patterns:

- Detection and Remediation
- Custom Compliance
- Intune Platform Scripts
- PowerShell Scripts Packaged as Win32 Apps

All examples are self-contained, use PowerShell 5.1-compatible syntax, avoid tenant-specific values, and place editable values in a clearly marked configuration section.

## Repository Principles

- One folder per deployable Intune script package.
- One README per script folder.
- One clear Intune workload per folder.
- One shared purpose category under each workload folder.
- Configuration values at the top of each script.
- Predictable exit codes and minimal output for clean Intune reporting.
- No tenant-specific hardcoding.
- Examples first, reusable templates second, operational docs always close by.

## Repository Layout

```text
.
|-- Custom-Compliance/
|   |-- Compliance/
|   |   `-- Example-Check-BitLocker-Status/
|   |-- Security/
|   `-- ...
|-- Detection-Remediation/
|   |-- Maintenance/
|   |   `-- Example-Ensure-Service-Running/
|   |-- Security/
|   `-- ...
|-- Intune-Platform-Scripts/
|   |-- Device-Configuration/
|   |   `-- Example-Set-TimeZone/
|   `-- ...
|-- Win32-Packaged-Scripts/
|   |-- Device-Configuration/
|   |   `-- Example-Install-Registry-Setting/
|   `-- ...
|-- docs/
|-- templates/
|-- tools/
|-- .github/
|-- SCRIPT-CATALOG.md
|-- CONTRIBUTING.md
|-- LICENSE
|-- README.md
`-- .gitignore
```

## Quick Start

1. Clone or download this repository.
2. Read `docs/Intune-Workload-Contracts.md` and choose the workload by how Intune must execute it.
3. Choose the purpose category that matches the script, such as `Security`, `Maintenance`, or `Device-Configuration`.
4. Copy an example folder or start from a template.
5. Open each script and edit only the values in the `CONFIGURATION` section first.
6. Test locally on a non-production device.
7. Deploy to a small pilot group in Intune.
8. Review Intune Management Extension logs and script-specific logs.
9. Expand deployment after expected behavior is confirmed.

## Copy And Customize Pattern

Every deployable script is written so technicians can customize it without hunting through the full script body:

- Start at the `CONFIGURATION` section.
- Look for `CUSTOMIZE HERE`.
- Change paths, registry keys, service names, URLs, expected values, tenant labels, and timing values there.
- Leave the logging and main control flow alone until the basic configuration has been tested.
- Review the script README for Intune settings, expected results, common failures, and log paths.

## Categories

The workload names below describe different Intune execution contracts. They are not interchangeable with topical purpose categories. See `docs/Intune-Workload-Contracts.md` for the required files, output, exit codes, run behavior, and promotion checks.

### Detection and Remediation

Use this category for Intune Remediations, formerly called Proactive Remediations. A detection script checks whether a condition is compliant. A remediation script runs only when detection exits with code `1`.

Example: `Detection-Remediation/Maintenance/Example-Ensure-Service-Running`

For Defender Secure Score style registry or security setting enforcement, this is usually the right category.

### Custom Compliance

Use this category when a compliance policy needs to evaluate settings that are not available in built-in Intune compliance settings. A discovery script returns compressed JSON, and a separate JSON rule file defines the expected values.

Example: `Custom-Compliance/Compliance/Example-Check-BitLocker-Status`

### Intune Platform Scripts

Use this category for one-time or change-triggered PowerShell scripts delivered by the Intune Management Extension.

Example: `Intune-Platform-Scripts/Device-Configuration/Example-Set-TimeZone`

### Win32 Packaged Scripts

Use this category when a PowerShell script should behave like an application with install, uninstall, and detection logic. Package the folder with the Microsoft Win32 Content Prep Tool.

Example: `Win32-Packaged-Scripts/Device-Configuration/Example-Install-Registry-Setting`

## Purpose Categories

Each workload folder uses the same category foundation:

- `Security`
- `Compliance`
- `Device-Configuration`
- `Applications`
- `Maintenance`
- `Endpoint-Health`
- `Networking`
- `User-Experience`
- `Inventory-Reporting`
- `Windows-Updates`
- `Browser-Management`
- `Remote-Work`
- `Identity-Access`
- `Printing`
- `Certificates-PKI`
- `Hardware-Drivers`
- `Power-Battery`
- `Backup-Recovery`
- `MDM-Enrollment`
- `Data-Protection`
- `Storage-Disk`
- `Troubleshooting-Support`
- `Peripheral-Devices`
- `Licensing-Activation`

## Intune Notes

- Test 32-bit and 64-bit PowerShell behavior. Registry and file system redirection can change results.
- Use system context for machine-wide settings such as services, HKLM registry keys, BitLocker, and time zone configuration.
- Use user context only when the script changes HKCU, user profile files, or user-specific settings.
- Remediation detection scripts should exit `0` when no issue is found and `1` when remediation should run.
- Win32 custom detection scripts must exit `0` and write output to STDOUT when the app is detected.
- Custom compliance discovery scripts should return only compressed JSON to STDOUT.
- Keep tenant IDs, group IDs, app IDs, secrets, and environment-specific paths out of scripts.

## Logging Convention

Scripts write logs using this pattern:

```text
C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\<ScriptPackageName>\<ScriptName>.log
```

Example:

```text
C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Example-Ensure-Service-Running\Detect.log
```

Each script sets `$ScriptPackageName` to the folder name and `$ScriptName` to the script file name without `.ps1`. The validation tool checks these values so logs stay predictable as the repository grows.

## Documentation

- `SCRIPT-CATALOG.md`
- `docs/Copy-And-Customize-Workflow.md`
- `docs/Intune-Workload-Contracts.md`
- `docs/Repository-Structure.md`
- `docs/Naming-Conventions.md`
- `docs/Intune-Execution-Context.md`
- `docs/Intune-Exit-Codes.md`
- `docs/Packaging-Win32-Apps.md`
- `docs/Logging-and-Error-Handling.md`
- `docs/Teams-Failure-Alerting.md`
- `docs/Script-Quality-Checklist.md`
- `docs/Safe-Pilot-Testing.md`
- `docs/Detection-Smoke-Testing.md`
- `docs/Detection-Evidence-Audit.md`
- `docs/Script-Portability-Audit.md`
- `docs/Script-Metadata-And-Catalog.md`
- `docs/Defender-Secure-Score-Remediation-Pattern.md`
- `docs/Open-Source-Inspiration-And-Credits.md`
- `docs/Business-Premium-Scope.md`

## Templates

Use the files in `templates/` when adding new scripts. Each template includes the documentation sections admins should expect before they deploy a script.

## Maintainer Tools

Run the repository validation script before publishing changes:

```powershell
.\tools\Test-Repository.ps1
.\tools\Test-IntuneWorkloadContracts.ps1
```

Update the generated catalog after adding or editing script metadata:

```powershell
.\tools\Update-ScriptCatalog.ps1
```

Smoke-test detection scripts locally before publishing a large batch:

```powershell
.\tools\Test-DetectionSmoke.ps1 -ListOnly
.\tools\Test-DetectionSmoke.ps1 -MaxScripts 10
.\tools\Test-DetectionSmoke.ps1
```

Audit whether detection scripts use real evidence or marker-only checks:

```powershell
.\tools\Test-DetectionEvidence.ps1
.\tools\Test-DetectionEvidence.ps1 -UpdateScriptInfo
.\tools\Test-DetectionEvidence.ps1 -Check
```

Audit scripts for language, OS-version, registry-view, path, command-parsing, and scalability risks:

```powershell
.\tools\Test-ScriptPortability.ps1
.\tools\Test-ScriptPortability.ps1 -UpdateScriptInfo -UpdateBaseline
.\tools\Test-ScriptPortability.ps1 -Check
```

Create a starter folder from repository conventions:

```powershell
.\tools\New-IntuneScriptFolder.ps1 -Workload Detection-Remediation -ScriptCategory Security -Name Defender-Example-Recommendation
```

Create a more filled-out starter folder:

```powershell
.\tools\New-IntuneScriptFolder.ps1 `
    -Workload Detection-Remediation `
    -ScriptCategory Security `
    -Name Defender-Example-Recommendation `
    -Summary 'Detects and remediates an example Defender recommendation.' `
    -Context System `
    -Requires64Bit
```

Include the optional Teams failure alert block in supported action scripts:

```powershell
.\tools\New-IntuneScriptFolder.ps1 -Workload Detection-Remediation -ScriptCategory Security -Name Defender-Example-Recommendation -IncludeTeamsAlertBlock
```

Useful generator options:

- `-Summary` fills starter script and README descriptions.
- `-Context System` or `-Context User` fills execution-context guidance.
- `-Requires64Bit` fills 64-bit PowerShell guidance.
- `-WritesTo`, `-Risk`, and `-Reboot` prefill `ScriptInfo.json`.
- `-IncludeTeamsAlertBlock` adds optional alerting to supported action scripts.

New packages are generated with `Status` set to `Template` and workload-specific starter logic. Replace every `IMPLEMENT WORKLOAD LOGIC` section, complete the evidence and portability reviews, and pass `tools\Test-IntuneWorkloadContracts.ps1` before promotion to `PilotReady`.

## Microsoft References

- [Remediations in Microsoft Intune](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations)
- [Use PowerShell scripts on Windows devices in Intune](https://learn.microsoft.com/en-us/intune/device-management/tools/run-powershell-scripts-windows)
- [Custom compliance discovery scripts](https://learn.microsoft.com/en-us/intune/device-security/compliance/create-custom-script)
- [Custom compliance JSON files](https://learn.microsoft.com/en-us/intune/device-security/compliance/create-custom-json)
- [Add and assign Win32 apps](https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32)

## Open Source Credits

Some script ideas are inspired by public Intune Remediations and Proactive Remediations examples from Microsoft docs, GitHub repositories, and GitHub gists. See `docs/Open-Source-Inspiration-And-Credits.md` for attribution and guidance.

## Support Statement

These scripts are examples and starting points. Always review, test, and adapt them to your organization's security, privacy, change control, and endpoint management requirements before production deployment.
