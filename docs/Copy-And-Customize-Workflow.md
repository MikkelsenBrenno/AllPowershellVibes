# Copy And Customize Workflow

This repository is meant to be copied from. A technician should be able to open a folder, see what to change, test it, and deploy it without reverse-engineering the whole script.

## Recommended Flow

1. Open `SCRIPT-CATALOG.md`.
2. Pick the closest script package.
3. Copy the whole package folder into your own working area.
4. Open the package `README.md`.
5. Review `What To Change First`.
6. Open each `.ps1` file and edit only the `CONFIGURATION` section first.
7. Keep `$ScriptPackageName` aligned with the folder name.
8. Keep `$ScriptName` aligned with the script file name without `.ps1`.
9. Test locally in the same context you will use in Intune.
10. Deploy to a small pilot group.
11. Review Intune Management Extension logs and script-specific logs.
12. Expand deployment after behavior is confirmed.

## What Not To Change First

Do not start by changing logging, exit handling, or the main control flow. Most customization should be values such as:

- File paths.
- Registry paths and value names.
- Service names.
- App names.
- URLs.
- Tenant labels.
- Expected values.
- Safety switches.
- Validation timing.

## Safety Switches

Some scripts are report-only by default. Look for settings such as:

- `$ApplyPolicy`
- `$ClearCacheItems`
- `$DeleteCacheItems`
- `$RemoveTask`
- `$CreateOrUpdateRule`
- `$DisableAccountIfPresent`

Leave these disabled until detection output proves the script targets exactly what you expect.

## Logs

Scripts write logs here:

```text
C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\<ScriptPackageName>\<ScriptName>.log
```

Keep this convention so technicians can troubleshoot every package the same way.
