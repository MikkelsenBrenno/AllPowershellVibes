# Ensure Folder Exists With Permissions

## Summary

This remediation package creates a configured folder and can optionally enforce one allow ACL entry.

## Files

- `Detect.ps1` - Checks the folder and optional ACL.
- `Remediate.ps1` - Creates the folder and optional ACL.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$FolderPath` | Folder to create and validate. | `C:\ProgramData\IntuneScriptLibrary\ExampleManagedFolder` |
| `$ValidateAclEntry` | Check ACL in detection. | `$false` |
| `$ConfigureAclEntry` | Add ACL in remediation. | `$false` |
| `$AclIdentity` | Identity for the ACL entry. | `BUILTIN\Users` |
| `$AclRight` | File-system right to check or grant. | `ReadAndExecute` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended for ProgramData or protected paths.

## Customization

Enable ACL validation only after confirming the identity and rights are correct for your environment.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | No unless your path requires it |

## Intune Deployment

Deploy to a pilot group and inspect the resulting folder and ACL.

## Exit Codes

- Detection `0` - Folder and optional ACL are compliant.
- Detection `1` - Folder or optional ACL is missing.
- Remediation `0` - Folder and optional ACL are configured.
- Remediation `1` - Configuration failed.

## Expected Results

The configured folder exists and optional ACL is present when enabled.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Folder-Exists-With-Permissions`.
- Confirm the account identity resolves on the target device.
- Confirm the script context can create the folder.

## Common Failures

- Localized built-in group names differ from the configured identity.
- ACL validation is enabled in detection but not configured in remediation.
