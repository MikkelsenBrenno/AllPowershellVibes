# Business Premium Scope

This repository is focused on scripts that are useful with Microsoft 365 Business Premium environments.

Scripts should avoid dependencies that require Microsoft 365 E5, Windows Enterprise E5, Defender for Endpoint Plan 2, advanced hunting, Purview E5, Sentinel, or other add-ons unless the README clearly marks the requirement and explains the alternative.

## Preferred Script Targets

- Microsoft Intune device management.
- Intune Remediations and platform scripts.
- Microsoft Defender for Business local configuration and health signals.
- Windows Update for Business settings available to Business Premium tenants.
- Entra ID joined or hybrid joined Windows devices.
- Microsoft 365 Apps for business or enterprise Click-to-Run state.
- OneDrive Known Folder Move and sync client health.
- BitLocker state and recovery-key operational checks.
- Local Windows security baseline settings that can be configured with Intune.

## Authoring Guidance

- Keep tenant-specific values out of repository copies.
- Use report-only defaults when remediation could remove apps, delete files, change security posture, or affect sign-in.
- Prefer local evidence that Business Premium admins can collect without E5-only APIs.
- Document whether the script should run as system or user.
- Keep source inspiration and credits in `docs/Open-Source-Inspiration-And-Credits.md`.
