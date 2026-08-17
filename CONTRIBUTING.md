# Contributing

Thank you for helping improve this Microsoft Intune PowerShell script library.

This repository is designed for IT administrators, so contributions should be practical, readable, and safe to customize.

## Contribution Standards

- Use PowerShell 5.1-compatible syntax unless the script clearly requires a newer runtime.
- Avoid tenant-specific hardcoding such as tenant IDs, app IDs, group IDs, domains, usernames, or secrets.
- Put all editable values in a clearly marked `CONFIGURATION` section.
- Add comments explaining what administrators should change.
- Include basic logging and error handling.
- Use predictable exit codes for the Intune workload.
- Keep each script self-contained unless there is a strong reason to share a helper.
- Include a README for every script folder.

## Naming

Follow `docs/Naming-Conventions.md`.

Folder names should be descriptive and use Pascal-style words separated by hyphens, for example:

```text
Example-Ensure-Service-Running
Configure-Company-Portal-Shortcut
Detect-Unsupported-Local-Admins
```

## Pull Request Checklist

Before opening a pull request:

- Confirm the script belongs in the correct workload and purpose category.
- Confirm the script has a standardized header.
- Confirm all customization values are in the `CONFIGURATION` section.
- Confirm the README explains prerequisites, deployment, expected results, and troubleshooting.
- Confirm `ScriptInfo.json` is present and accurate.
- Confirm the script was tested locally.
- Confirm the script was tested in the expected execution context, such as system or user.
- Confirm the script handles errors without exposing sensitive information.
- Confirm no generated logs, packaged `.intunewin` files, or secrets are committed.
- If the idea came from a public repository, gist, blog, or documentation page, add attribution to `docs/Open-Source-Inspiration-And-Credits.md` and mention direct inspiration in the package README when appropriate.
- Run `tools\Update-ScriptCatalog.ps1`.
- Run `tools\Test-Repository.ps1`.

## Security

Do not include:

- Passwords, tokens, certificates, or private keys.
- Tenant-specific IDs unless they are fake placeholders.
- Real user data, device names, hostnames, or internal URLs.
- Commands that disable security controls without a clear and documented purpose.

If you find a security issue, do not open a public issue with exploit details. Use your organization's responsible disclosure process or repository security reporting process.

## Documentation Expectations

Every script folder README should include:

- What the script does.
- Prerequisites.
- Customization points.
- How to deploy in Intune.
- Expected results.
- Troubleshooting tips.

## Testing Guidance

Recommended local testing steps:

1. Run the script from an elevated PowerShell 5.1 console when system-level changes are required.
2. Test in both 32-bit and 64-bit PowerShell when registry or file system paths are involved.
3. Test as the local system account for Intune system-context scripts.
4. Confirm logs are created under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\<ScriptPackageName>\<ScriptName>.log`.
5. Confirm exit codes match the README.

## Adding a New Script Folder

You can create a starter folder with:

```powershell
.\tools\New-IntuneScriptFolder.ps1 -Workload Detection-Remediation -ScriptCategory Security -Name Defender-Example-Recommendation
```

Add `-IncludeTeamsAlertBlock` when a supported action script should include the optional Teams failure alerting block. The block stays disabled by default until an admin sets `$EnableTeamsFailureAlert = $true` and provides a webhook URL in their deployed copy.

The generator also creates `ScriptInfo.json`. Update that metadata before regenerating `SCRIPT-CATALOG.md`.

Supported workloads:

- `Detection-Remediation`
- `Custom-Compliance`
- `Intune-Platform-Scripts`
- `Win32-Packaged-Scripts`

Supported purpose categories:

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

## Style

Prefer clear PowerShell over clever PowerShell. Many administrators will use these scripts as learning material, so readability matters.
