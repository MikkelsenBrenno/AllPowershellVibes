# Logging and Error Handling

Good logs make Intune scripts easier to support when they run outside an interactive administrator session.

## Standard Log Location

Scripts in this repository write logs to:

```text
C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\<ScriptPackageName>\<ScriptName>.log
```

This keeps logs easy to find and prevents collisions between common Intune script names such as `Detect.ps1`.

Example:

```text
C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Example-Ensure-Service-Running\Detect.log
```

This path works well for system-context scripts and does not depend on a signed-in user's profile.

## Logging Pattern

Use script identity values and a small helper function in each script:

```powershell
$ScriptPackageName = 'Example-Ensure-Service-Running'
$ScriptName = 'Detect'

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"
```

```powershell
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "$timestamp [$Level] $Message"
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}
```

Each script should also log metadata at the start of a run:

```powershell
function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}
```

## Error Handling Pattern

Set strict error behavior at the top of scripts:

```powershell
$ErrorActionPreference = 'Stop'
```

Wrap main logic in `try` and `catch`:

```powershell
try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message 'Script started.'

    # Main logic here.

    Write-Log -Message 'Script completed successfully.'
    exit 0
}
catch {
    try {
        Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
        # Do not hide the original failure if logging fails.
    }

    exit 1
}
```

## STDOUT Guidance

Use STDOUT intentionally:

- Remediation scripts can write short status messages.
- Platform scripts can write short status messages.
- Win32 detection scripts must write a string to STDOUT when detected.
- Custom compliance scripts should write only compressed JSON to STDOUT.

## Optional Teams Failure Alerts

Use `templates/TeamsFailureAlert.Template.ps1` when a remediation, install, or uninstall failure should send a Microsoft Teams alert.

Keep alerting disabled by default and never commit a real webhook URL. When `$EnableTeamsFailureAlert` is `$false`, the alert function silently returns and does not affect the script's Intune exit code. See `docs/Teams-Failure-Alerting.md`.

## What to Log

Log:

- Script start and end.
- Configuration values that are safe to record.
- Current state before change.
- Change attempt.
- Validation result.
- Error message and exception type.

Do not log:

- Passwords.
- Tokens.
- Certificate private keys.
- Full user data.
- Sensitive internal URLs unless approved.

## Exit Code Discipline

Only exit `0` after the script has validated success. Exit `1` when an expected state could not be confirmed.

For remediations, remember that detection exit `1` means "issue found" rather than "script crashed."
