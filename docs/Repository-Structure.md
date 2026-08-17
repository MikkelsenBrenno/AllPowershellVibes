# Repository Structure

This repository is organized as a script library, not a single-purpose script drop.

The main design goal is simple: an administrator should know where a script belongs, how to customize it, how to deploy it, and how to troubleshoot it without reading every other folder.

## Root Files

| File | Purpose |
| --- | --- |
| `README.md` | Main repository entry point |
| `SCRIPT-CATALOG.md` | Quick index of available scripts |
| `CONTRIBUTING.md` | Rules for adding or changing scripts |
| `LICENSE` | Repository license |
| `.gitignore` | Prevents local output, logs, packages, and secrets from being committed |

## Root Folders

| Folder | Purpose |
| --- | --- |
| `Detection-Remediation` | Intune Remediations detection and remediation pairs |
| `Custom-Compliance` | Custom compliance discovery scripts and JSON rules |
| `Intune-Platform-Scripts` | Standalone Intune platform scripts |
| `Win32-Packaged-Scripts` | Script packages deployed as Win32 apps |
| `docs` | Repository standards and operational guidance |
| `templates` | Copyable templates for new scripts and README files |
| `tools` | Local helper scripts for maintainers |
| `.github` | GitHub issue, pull request, and validation workflow files |

## Script Folder Standard

Scripts live three levels deep:

```text
<Workload>/<Purpose-Category>/<Script-Folder>/
```

Example:

```text
Detection-Remediation/Security/Defender-Enable-Network-Protection/
```

Every script folder must include:

- A `README.md`.
- One complete deployable unit.
- A clearly marked `CONFIGURATION` section in every script.
- Logging and error handling.
- Intune deployment instructions.
- Expected results and troubleshooting notes.

## Why Use One Folder Per Script

One folder per deployable script keeps the library easy to operate:

- Admins can download a single folder.
- README instructions stay close to the scripts.
- Detection and remediation pairs do not get mixed up.
- Intune assignment and reporting can map to one folder and one purpose.
- Future automation can build a catalog from predictable locations.

## Purpose Category Foundation

Each workload folder uses the same purpose categories:

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

This keeps the repository stable as it grows. A script should move between workloads only if the Intune deployment method changes.

## Recommended Naming by Scenario

| Scenario | Folder Name Example |
| --- | --- |
| General example | `Example-Ensure-Service-Running` |
| Defender recommendation | `Defender-Disable-Anonymous-Enumeration` |
| BitLocker check | `Check-BitLocker-Status` |
| Device configuration | `Set-TimeZone` |
| Win32 package | `Install-Registry-Setting` |

## Repository Growth Model

As the repository grows, add scripts under the existing four workload categories. Avoid creating new root folders unless the script uses a different Intune deployment model.

Good:

```text
Detection-Remediation/
`-- Security/
    `-- Defender-Enable-Network-Protection/
```

Avoid:

```text
Defender/
`-- Network-Protection/
```

The first pattern keeps the deployment model obvious. The second pattern hides how the script is meant to be used in Intune.
