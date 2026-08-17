<#
.SYNOPSIS
    Generates SCRIPT-CATALOG.md from ScriptInfo.json files.

.DESCRIPTION
    Maintainer tool for this Intune script library. The script reads
    ScriptInfo.json from each script package folder and builds the repository
    catalog. Use -InitializeMissingScriptInfo once to create metadata files
    for existing script folders. Use -Check in CI to verify the catalog is
    current.

.NOTES
    Name:        Update-ScriptCatalog.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     Local maintainer
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path,

    [switch]$Check,

    [switch]$InitializeMissingScriptInfo
)

$ErrorActionPreference = 'Stop'

$workloadDisplayNames = @{
    'Detection-Remediation' = 'Detection and Remediation'
    'Custom-Compliance' = 'Custom Compliance'
    'Intune-Platform-Scripts' = 'Intune Platform Scripts'
    'Win32-Packaged-Scripts' = 'Win32 Packaged Scripts'
}

$requiredFields = @(
    'Name',
    'Workload',
    'Purpose',
    'Status',
    'Context',
    'Requires64BitPowerShell',
    'HasRemediation',
    'HasUninstall',
    'TeamsAlertReady',
    'WritesTo',
    'Reboot',
    'Risk',
    'DetectionEvidenceType',
    'DetectionEvidenceSource',
    'DetectionReviewStatus',
    'PortabilityReviewStatus',
    'PortabilityRiskLevel',
    'PortabilityRiskAreas',
    'PortabilityNotes',
    'Summary'
)

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $baseUri = New-Object System.Uri(($BasePath.TrimEnd('\') + '\'))
    $pathUri = New-Object System.Uri($Path)
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('/', '\')
}

function ConvertTo-DisplayName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderName
    )

    $displayName = ($FolderName -replace '-', ' ')
    $displayName = $displayName -replace '\bTpm\b', 'TPM'
    $displayName = $displayName -replace '\bPua\b', 'PUA'
    $displayName = $displayName -replace '\bIme\b', 'IME'
    $displayName = $displayName -replace '\bKfm\b', 'KFM'
    $displayName = $displayName -replace '\bVpn\b', 'VPN'
    $displayName = $displayName -replace '\bNtp\b', 'NTP'
    return $displayName
}

function Get-ReadmeSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReadmePath
    )

    if (-not (Test-Path -LiteralPath $ReadmePath -PathType Leaf)) {
        return ''
    }

    $content = Get-Content -LiteralPath $ReadmePath -Raw
    $match = [regex]::Match($content, '(?ms)^##\s+Summary\s*(?<summary>.*?)(^##\s+|\z)')

    if (-not $match.Success) {
        return ''
    }

    $summaryLines = $match.Groups['summary'].Value -split '\r?\n' |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if ($summaryLines.Count -eq 0) {
        return ''
    }

    return ($summaryLines -join ' ')
}

function Get-FolderText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )

    $textFiles = Get-ChildItem -LiteralPath $FolderPath -File -Include '*.ps1', '*.md', '*.json' -ErrorAction SilentlyContinue
    $parts = foreach ($file in $textFiles) {
        Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    }

    return ($parts -join "`n")
}

function New-InferredScriptInfo {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$ScriptFolder,

        [Parameter(Mandatory = $true)]
        [string]$WorkloadFolderName,

        [Parameter(Mandatory = $true)]
        [string]$Purpose
    )

    $content = Get-FolderText -FolderPath $ScriptFolder.FullName
    $readmePath = Join-Path -Path $ScriptFolder.FullName -ChildPath 'README.md'
    $summary = Get-ReadmeSummary -ReadmePath $readmePath

    if ([string]::IsNullOrWhiteSpace($summary)) {
        $summary = "Example package for $($ScriptFolder.Name)."
    }

    $hasRemediation = if (Test-Path -LiteralPath (Join-Path -Path $ScriptFolder.FullName -ChildPath 'Remediate.ps1')) { 'Yes' } elseif ($WorkloadFolderName -eq 'Intune-Platform-Scripts' -or $WorkloadFolderName -eq 'Win32-Packaged-Scripts') { 'N/A' } else { 'No' }
    $hasUninstall = if (Test-Path -LiteralPath (Join-Path -Path $ScriptFolder.FullName -ChildPath 'Uninstall.ps1')) { 'Yes' } else { 'No' }
    $teamsAlertReady = if ($content -match 'TeamsWebhook|TeamsFailureAlert') { 'Yes' } else { 'No' }

    if ($WorkloadFolderName -eq 'Custom-Compliance') {
        $writesTo = 'JSON output only'
        $risk = 'Low'
    }
    elseif ($content -match 'Set-MpPreference') {
        $writesTo = 'Defender preference'
        $risk = 'High'
    }
    elseif ($content -match 'New-NetFirewallRule|Set-NetFirewallRule') {
        $writesTo = 'Firewall policy'
        $risk = 'High'
    }
    elseif ($content -match 'Cert:\\|X509Store|Import-Certificate') {
        $writesTo = 'Certificate store'
        $risk = 'High'
    }
    elseif ($content -match 'Unregister-ScheduledTask|Disable-LocalUser|Remove-LocalGroupMember') {
        $writesTo = 'Local device security state'
        $risk = 'High'
    }
    elseif ($content -match 'Remove-Item|Remove-Printer|Remove-SmbMapping') {
        $writesTo = 'File system or local configuration removal'
        $risk = 'High'
    }
    elseif ($content -match 'HKLM:|HKCU:|Set-ItemProperty|New-ItemProperty|Remove-ItemProperty') {
        $writesTo = 'Registry'
        $risk = 'Medium'
    }
    elseif ($content -match 'New-Item|Copy-Item|Set-Content') {
        $writesTo = 'File system'
        $risk = 'Medium'
    }
    elseif ($content -match 'Start-Service|Restart-Service|Set-Service') {
        $writesTo = 'Service control'
        $risk = 'Medium'
    }
    else {
        $writesTo = 'Logs only'
        $risk = 'Low'
    }

    $requires64Bit = if ($content -match 'HKLM:|System32|Program Files|Get-LocalUser') { 'Recommended for native Windows paths' } else { 'Recommended' }
    $reboot = if ($ScriptFolder.Name -match 'Pending-Reboot') { 'Yes to remediate' } else { 'No' }

    if ($WorkloadFolderName -eq 'Intune-Platform-Scripts') {
        $detectionEvidenceType = 'N/A'
        $detectionEvidenceSource = 'No detection script for this workload'
        $detectionReviewStatus = 'NotApplicable'
    }
    else {
        $detectionEvidenceType = 'NeedsReview'
        $detectionEvidenceSource = 'Generated package has not been evidence-audited'
        $detectionReviewStatus = 'NeedsReview'
    }

    $portabilityReviewStatus = 'NeedsReview'
    $portabilityRiskLevel = 'Medium'
    $portabilityRiskAreas = @(
        'Localization',
        'OsVersion',
        'CommandParsing',
        'Scalability',
        'RegistryView',
        'PathAssumption'
    )
    $portabilityNotes = 'Generated package has not been portability-audited'

    return [ordered]@{
        Name = ConvertTo-DisplayName -FolderName $ScriptFolder.Name
        Workload = $workloadDisplayNames[$WorkloadFolderName]
        Purpose = $Purpose
        Status = 'Example'
        Context = 'System'
        Requires64BitPowerShell = $requires64Bit
        HasRemediation = $hasRemediation
        HasUninstall = $hasUninstall
        TeamsAlertReady = $teamsAlertReady
        WritesTo = $writesTo
        Reboot = $reboot
        Risk = $risk
        DetectionEvidenceType = $detectionEvidenceType
        DetectionEvidenceSource = $detectionEvidenceSource
        DetectionReviewStatus = $detectionReviewStatus
        PortabilityReviewStatus = $portabilityReviewStatus
        PortabilityRiskLevel = $portabilityRiskLevel
        PortabilityRiskAreas = $portabilityRiskAreas
        PortabilityNotes = $portabilityNotes
        Summary = $summary
        Tags = @($Purpose, $WorkloadFolderName)
    }
}

function Test-ScriptInfo {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$ScriptInfo,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    foreach ($field in $requiredFields) {
        if (-not $ScriptInfo.PSObject.Properties.Name.Contains($field)) {
            throw "ScriptInfo field '$field' is missing in '$Path'."
        }

        if ($field -eq 'PortabilityRiskAreas') {
            continue
        }

        if ([string]::IsNullOrWhiteSpace([string]$ScriptInfo.$field)) {
            throw "ScriptInfo field '$field' is empty in '$Path'."
        }
    }
}

function Format-MarkdownCell {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -is [System.Array]) {
        return ((@($Value) | ForEach-Object { [string]$_ }) -join ', ').Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ').Trim()
    }

    return ([string]$Value).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ').Trim()
}

function Get-ScriptFolders {
    foreach ($workloadFolderName in $workloadDisplayNames.Keys) {
        $workloadPath = Join-Path -Path $RepositoryRoot -ChildPath $workloadFolderName

        if (-not (Test-Path -LiteralPath $workloadPath -PathType Container)) {
            continue
        }

        $purposeFolders = Get-ChildItem -LiteralPath $workloadPath -Directory | Sort-Object -Property Name

        foreach ($purposeFolder in $purposeFolders) {
            $scriptFolders = Get-ChildItem -LiteralPath $purposeFolder.FullName -Directory | Sort-Object -Property Name

            foreach ($scriptFolder in $scriptFolders) {
                [pscustomobject]@{
                    WorkloadFolderName = $workloadFolderName
                    Purpose = $purposeFolder.Name
                    Folder = $scriptFolder
                }
            }
        }
    }
}

$scriptItems = foreach ($scriptFolderInfo in Get-ScriptFolders) {
    $scriptFolder = $scriptFolderInfo.Folder
    $scriptInfoPath = Join-Path -Path $scriptFolder.FullName -ChildPath 'ScriptInfo.json'

    if (-not (Test-Path -LiteralPath $scriptInfoPath -PathType Leaf)) {
        if (-not $InitializeMissingScriptInfo) {
            throw "Missing ScriptInfo.json in '$($scriptFolder.FullName)'. Run tools\Update-ScriptCatalog.ps1 -InitializeMissingScriptInfo to create starter metadata."
        }

        $newInfo = New-InferredScriptInfo -ScriptFolder $scriptFolder -WorkloadFolderName $scriptFolderInfo.WorkloadFolderName -Purpose $scriptFolderInfo.Purpose
        $newInfo | ConvertTo-Json -Depth 8 | Set-Content -Path $scriptInfoPath -Encoding UTF8
    }

    $scriptInfo = Get-Content -LiteralPath $scriptInfoPath -Raw | ConvertFrom-Json
    Test-ScriptInfo -ScriptInfo $scriptInfo -Path $scriptInfoPath

    [pscustomobject]@{
        Info = $scriptInfo
        Path = (Get-RelativePath -BasePath $RepositoryRoot -Path $scriptFolder.FullName).Replace('\', '/')
    }
}

$orderedItems = $scriptItems | Sort-Object -Property @{ Expression = { $_.Info.Workload } }, @{ Expression = { $_.Info.Purpose } }, @{ Expression = { $_.Info.Name } }

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Script Catalog')
$lines.Add('')
$lines.Add('This catalog is generated from `ScriptInfo.json` files in each script folder.')
$lines.Add('')
$lines.Add('To update it after changing script metadata, run:')
$lines.Add('')
$lines.Add('```powershell')
$lines.Add('.\tools\Update-ScriptCatalog.ps1')
$lines.Add('```')
$lines.Add('')
$lines.Add('## Status Legend')
$lines.Add('')
$lines.Add('| Status | Meaning |')
$lines.Add('| --- | --- |')
$lines.Add('| Example | Working example intended for customization |')
$lines.Add('| Template | Starting point for a new script |')
$lines.Add('| Planned | Placeholder for a future contribution |')
$lines.Add('')
$lines.Add('## Risk Legend')
$lines.Add('')
$lines.Add('| Risk | Meaning |')
$lines.Add('| --- | --- |')
$lines.Add('| Low | Read-only, reporting, or simple additive change |')
$lines.Add('| Medium | Changes device/user configuration and should be piloted |')
$lines.Add('| High | Changes security state, deletes data, changes trust, or can remove access |')
$lines.Add('')
$lines.Add('## Detection Evidence Legend')
$lines.Add('')
$lines.Add('| Evidence Type | Meaning |')
$lines.Add('| --- | --- |')
$lines.Add('| DirectEvidence | Detection reads a recognized device evidence source directly |')
$lines.Add('| SnapshotFreshness | Detection validates that a snapshot file exists and is current |')
$lines.Add('| PackageMarker | Win32 detection uses a package-owned install/version marker |')
$lines.Add('| MarkerOnly | Detection only reads repository-managed marker state and needs review before being treated as real device-state compliance |')
$lines.Add('| NeedsReview | The audit could not identify a strong evidence source |')
$lines.Add('| N/A | The workload does not use a detection script contract |')
$lines.Add('')
$lines.Add('## Portability Legend')
$lines.Add('')
$lines.Add('| Field | Meaning |')
$lines.Add('| --- | --- |')
$lines.Add('| Portability Risk | Highest static audit risk: None, Low, Medium, or High |')
$lines.Add('| Portability Review | Reviewed, NeedsReview, or NotApplicable |')
$lines.Add('| Portability Areas | Localization, OsVersion, CommandParsing, Scalability, RegistryView, or PathAssumption findings |')
$lines.Add('')
$lines.Add('## Catalog')
$lines.Add('')
$lines.Add('| Name | Workload | Purpose | Status | Context | 64-bit PowerShell | Has Remediation | Has Uninstall | Teams Alert Ready | Writes To | Reboot | Risk | Evidence Type | Evidence Review | Evidence Source | Portability Risk | Portability Review | Portability Areas | Portability Notes | Summary | Path |')
$lines.Add('| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |')

foreach ($item in $orderedItems) {
    $info = $item.Info
    $lines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} | {12} | {13} | {14} | {15} | {16} | {17} | {18} | {19} | `{20}` |' -f
        (Format-MarkdownCell $info.Name),
        (Format-MarkdownCell $info.Workload),
        (Format-MarkdownCell $info.Purpose),
        (Format-MarkdownCell $info.Status),
        (Format-MarkdownCell $info.Context),
        (Format-MarkdownCell $info.Requires64BitPowerShell),
        (Format-MarkdownCell $info.HasRemediation),
        (Format-MarkdownCell $info.HasUninstall),
        (Format-MarkdownCell $info.TeamsAlertReady),
        (Format-MarkdownCell $info.WritesTo),
        (Format-MarkdownCell $info.Reboot),
        (Format-MarkdownCell $info.Risk),
        (Format-MarkdownCell $info.DetectionEvidenceType),
        (Format-MarkdownCell $info.DetectionReviewStatus),
        (Format-MarkdownCell $info.DetectionEvidenceSource),
        (Format-MarkdownCell $info.PortabilityRiskLevel),
        (Format-MarkdownCell $info.PortabilityReviewStatus),
        (Format-MarkdownCell $info.PortabilityRiskAreas),
        (Format-MarkdownCell $info.PortabilityNotes),
        (Format-MarkdownCell $info.Summary),
        (Format-MarkdownCell $item.Path)))
}

$lines.Add('')
$lines.Add('## Recommended Folder Pattern')
$lines.Add('')
$lines.Add('Each script should live in its own folder and include:')
$lines.Add('')
$lines.Add('```text')
$lines.Add('<Workload>/')
$lines.Add('`-- <Purpose-Category>/')
$lines.Add('    `-- <Script-Folder-Name>/')
$lines.Add('        |-- ScriptInfo.json')
$lines.Add('        |-- README.md')
$lines.Add('        |-- <Required script files>')
$lines.Add('        `-- <Optional supporting files>')
$lines.Add('```')
$lines.Add('')
$lines.Add('## Adding a New Script')
$lines.Add('')
$lines.Add('1. Pick the correct workload.')
$lines.Add('2. Pick the correct purpose category.')
$lines.Add('3. Run `tools\New-IntuneScriptFolder.ps1` or copy the nearest example.')
$lines.Add('4. Keep the script self-contained.')
$lines.Add('5. Put all editable values in the `CONFIGURATION` section.')
$lines.Add('6. Update `ScriptInfo.json` and `README.md`.')
$lines.Add('7. Run `tools\Update-ScriptCatalog.ps1`.')
$lines.Add('8. Run `tools\Test-DetectionEvidence.ps1 -UpdateScriptInfo` when detection logic changes.')
$lines.Add('9. Run `tools\Test-ScriptPortability.ps1 -UpdateScriptInfo` when script logic changes.')
$lines.Add('10. Run `tools\Test-Repository.ps1` before publishing.')
$lines.Add('')
$lines.Add('## Generator Example')
$lines.Add('')
$lines.Add('```powershell')
$lines.Add('.\tools\New-IntuneScriptFolder.ps1 `')
$lines.Add('    -Workload Detection-Remediation `')
$lines.Add('    -ScriptCategory Security `')
$lines.Add('    -Name Defender-Example-Recommendation `')
$lines.Add('    -Summary ''Detects and remediates an example Defender recommendation.'' `')
$lines.Add('    -Context System `')
$lines.Add('    -Requires64Bit `')
$lines.Add('    -WritesTo ''Defender preference'' `')
$lines.Add('    -Risk High `')
$lines.Add('    -IncludeTeamsAlertBlock')
$lines.Add('```')
$lines.Add('')
$lines.Add('## Defender Secure Score Style Scripts')
$lines.Add('')
$lines.Add('For Microsoft Defender Secure Score recommendations that require registry enforcement, use `Detection-Remediation/Security` unless the setting needs app-like install/uninstall behavior.')
$lines.Add('')
$lines.Add('Recommended structure:')
$lines.Add('')
$lines.Add('```text')
$lines.Add('Detection-Remediation/')
$lines.Add('`-- Security/')
$lines.Add('    `-- Defender-<Recommendation-Short-Name>/')
$lines.Add('        |-- ScriptInfo.json')
$lines.Add('        |-- Detect.ps1')
$lines.Add('        |-- Remediate.ps1')
$lines.Add('        `-- README.md')
$lines.Add('```')
$lines.Add('')
$lines.Add('Use a folder per recommendation. This keeps Intune assignments, reporting, and troubleshooting clean.')

$catalogContent = ($lines -join "`r`n") + "`r`n"
$catalogPath = Join-Path -Path $RepositoryRoot -ChildPath 'SCRIPT-CATALOG.md'

if ($Check) {
    if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
        throw "Catalog '$catalogPath' does not exist."
    }

    $existingContent = Get-Content -LiteralPath $catalogPath -Raw

    if ($existingContent -ne $catalogContent) {
        Write-Output 'SCRIPT-CATALOG.md is not current. Run tools\Update-ScriptCatalog.ps1 and commit the result.'
        exit 1
    }

    Write-Output 'SCRIPT-CATALOG.md is current.'
    exit 0
}

Set-Content -Path $catalogPath -Value $catalogContent -Encoding UTF8 -NoNewline
Write-Output "Updated '$catalogPath' from ScriptInfo.json metadata."
