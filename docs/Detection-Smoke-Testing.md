# Detection Smoke Testing

Use `tools\Test-DetectionSmoke.ps1` to locally smoke-test repository detection scripts before publishing changes. The harness starts each detection in a fresh 64-bit Windows PowerShell 5.1 process from the package folder, captures the exit code and output, and writes reports under `output`.

This is smoke testing, not tenant policy validation. A local pass means the script can be discovered, launched, complete within the timeout, return an Intune-valid detection exit code, and produce a useful report. It does not prove the final compliant or noncompliant state that Intune will see on an enrolled production device.

## Scope

The harness tests these detection scripts:

```text
Detection-Remediation\*\*\Detect.ps1
Win32-Packaged-Scripts\*\*\Detect.ps1
```

Custom compliance `Discover.ps1` files are intentionally excluded. Those scripts need a separate JSON-output validation harness because Intune custom compliance uses a different contract.

## Commands

List discovered detections without running them:

```powershell
.\tools\Test-DetectionSmoke.ps1 -ListOnly
```

Run a small pilot batch:

```powershell
.\tools\Test-DetectionSmoke.ps1 -MaxScripts 10
```

Run the full detection smoke test:

```powershell
.\tools\Test-DetectionSmoke.ps1
```

Optional parameters:

- `-Scope AllDetect|Remediation|Win32` selects the script family. The default is `AllDetect`.
- `-TimeoutSeconds` controls the per-script timeout. The default is `60`.
- `-MaxScripts` limits execution for pilot runs.
- `-ListOnly` performs discovery and report generation without execution.
- `-OutputRoot` changes where JSON, CSV, and Markdown reports are written. The default is `output`.

## Reports And Logs

The harness writes these local reports:

```text
output\detection-smoke-results.json
output\detection-smoke-results.csv
output\detection-smoke-summary.md
```

Detection scripts keep their normal local logging behavior. Repository scripts write logs under:

```text
C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs
```

Keeping the real ProgramData log path is intentional because it gives maintainers the same evidence path technicians will use when troubleshooting copied scripts.

On a local non-admin workstation, creating folders under `C:\ProgramData\Microsoft` can be blocked even though Intune system-context scripts can write there during real deployment. The smoke summary records whether the ProgramData log root was writable for the current run. If it is not writable, detections may exit `1` with `could not be validated` output because their normal logging initialization failed.

## Pass Rules

Remediation detections pass when:

- The process starts successfully.
- The script does not time out.
- The exit code is `0` or `1`.

Win32 packaged detections pass when:

- The process starts successfully.
- The script does not time out.
- The exit code is `0` or `1`.
- If the exit code is `0`, STDOUT is not empty.

Hard failures include:

- PowerShell process launch failure.
- Timeout.
- Exit code other than `0` or `1`.
- Terminating error output captured through STDERR.

Review warnings include detections that exit `1` cleanly but print wording such as `failed`, `exception`, `access denied`, or `could not be validated`. Exit `1` can be normal noncompliance, so warnings should be reviewed before changing the script.

## Local Machine Limitations

This repository can be smoke-tested on a Windows Pro machine that is not connected to an Intune tenant. Some detections are expected to report noncompliance because tenant policy, management extensions, registry values, services, certificates, or security baselines may not exist locally.

Treat environment-related exit `1` results as useful evidence, not automatic bugs. The important smoke-test question is whether each detection starts, handles missing local state cleanly, logs enough information, and returns an Intune-valid exit code.
