# Defender Secure Score Remediation Pattern

Microsoft Defender Secure Score often recommends settings that can be configured through Intune security baselines, Settings Catalog, Endpoint Security policies, or Administrative Templates.

Use scripts only when the setting is not available through a native Intune policy, or when your organization has a documented reason to enforce it with Remediations.

## Recommended Category

Use:

```text
Detection-Remediation/Security/
```

This gives each recommendation:

- A read-only detection script.
- A remediation script that applies the expected value.
- Recurring drift correction through Intune Remediations.
- Clear reporting in Intune.

## Folder Pattern

```text
Detection-Remediation/
`-- Security/
    `-- Defender-<Recommendation-Short-Name>/
        |-- Detect.ps1
        |-- Remediate.ps1
        `-- README.md
```

Example:

```text
Detection-Remediation/
`-- Security/
    `-- Defender-Enable-Network-Protection/
        |-- Detect.ps1
        |-- Remediate.ps1
        `-- README.md
```

## Detection Pattern

Detection should:

- Read the exact registry value, PowerShell setting, service state, or Defender preference.
- Return `0` when the setting matches the preferred value.
- Return `1` when the setting is missing or different.
- Avoid changing the device.

## Remediation Pattern

Remediation should:

- Create missing registry paths only when needed.
- Set the expected value.
- Validate the final value.
- Exit `0` only after validation succeeds.

## README Requirements

For Defender Secure Score scripts, include:

- Secure Score recommendation name.
- Why native Intune policy was not used.
- Registry path or Defender preference being checked.
- Expected value.
- Context: usually system.
- 64-bit PowerShell guidance.
- Possible conflicts with security baselines, Settings Catalog, Endpoint Security, or GPO.
- Whether reboot, service restart, or user sign-out is required.

## Conflict Warning

Do not use a script to fight another policy. If a setting is managed by security baseline, Settings Catalog, Endpoint Security, GPO, or another remediation, fix the source of truth first.
