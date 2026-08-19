# Script Quality Checklist

Use this checklist before publishing or deploying a script.

## Repository Fit

- The script is in the correct workload folder.
- The script is in the correct purpose category folder.
- The folder name is descriptive and follows repository naming conventions.
- The folder contains only files needed for that script.
- The README explains the script without requiring prior knowledge of the repository.

## PowerShell Quality

- The script is compatible with Windows PowerShell 5.1.
- The script starts with a standardized header.
- Editable values are in the `CONFIGURATION` section.
- The `CONFIGURATION` section is easy to find near the top of the script.
- File paths, registry paths, service names, URLs, tenant labels, expected values, and timing values are not hidden in the script body.
- The script uses `try` and `catch`.
- The script validates the final state before exiting successfully.
- The script avoids tenant-specific hardcoding.
- The script avoids secrets and sensitive values.

## Intune Behavior

- Exit codes match the Intune workload.
- Detection scripts are read-only unless the README clearly explains otherwise.
- Remediation scripts run only the required change.
- Custom compliance discovery scripts output compressed JSON only.
- Win32 detection scripts write STDOUT when detected.
- The README states system or user context.
- The README states 32-bit or 64-bit PowerShell guidance.

## Logging

- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\<ScriptPackageName>\<ScriptName>.log`.
- `$ScriptPackageName` matches the script folder name.
- `$ScriptName` matches the script file name without `.ps1`.
- The first log entries include script metadata, user context, PowerShell version, and 32-bit or 64-bit process state.
- Logs include start, current state, attempted change, validation result, and failure message.
- Logs do not contain secrets or private user data.

## Optional Alerting

- Teams failure alerting is disabled by default unless explicitly required.
- Real Teams webhook URLs are not committed to the repository.
- Alerts include only safe failure detail and necessary troubleshooting context.
- Detection noncompliance does not trigger failure alerts unless the detection script itself fails unexpectedly.

## Documentation

- README includes summary, prerequisites, customization, Intune deployment, expected results, and troubleshooting.
- README includes install, uninstall, or detection commands when applicable.
- JSON rules are explained when applicable.
- Any known reboot, logoff, or service restart requirement is documented.
- `PilotReady` and `Validated` READMEs include a package-specific `Pilot Validation` section and relevant Microsoft Learn references.
- `Validated` READMEs include a non-sensitive `Validation Evidence` section.

## Testing

- Script syntax was validated.
- JSON files were validated.
- The script was tested locally.
- The script was tested in the same context Intune will use.
- Registry and file system behavior was tested in the intended 32-bit or 64-bit PowerShell host.
- Deployment was piloted before broad assignment.

Use `docs/Trusted-Remediation-Pilot.md` for the remediation handoff, pilot record, and status-promotion rules.
