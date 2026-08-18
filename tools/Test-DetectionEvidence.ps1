<#
.SYNOPSIS
    Audits detection scripts for evidence quality.

.DESCRIPTION
    Local maintainer tool for this Intune script library. The script discovers
    Custom Compliance discovery scripts, Remediation detection scripts, and
    Win32 detection scripts, then classifies whether each script verifies direct
    device evidence, package markers, snapshot freshness, marker-only state, or
    needs manual review.

    Use -UpdateScriptInfo to stamp ScriptInfo.json with the current
    classification. Use -Check in CI to verify those metadata fields remain
    current after code changes.

.NOTES
    Name:        Test-DetectionEvidence.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     Local maintainer
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateSet('All', 'CustomCompliance', 'Remediation', 'Win32', 'Platform')]
    [string]$Scope = 'All',

    [string]$RepositoryRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path,

    [string]$OutputRoot = (Join-Path -Path (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path -ChildPath 'output'),

    [switch]$UpdateScriptInfo,

    [switch]$Check,

    [switch]$FailOnNeedsReview,

    [string[]]$PackagePath,

    [switch]$SummaryOnly,

    [string]$ResultPath
)

$ErrorActionPreference = 'Stop'
$validationModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'IntuneLibrary.Validation.psm1'
Import-Module -Name $validationModulePath -Force
$selectedPackagePaths = @($PackagePath | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { ConvertTo-ValidationPath -Path $_ } | Sort-Object -Unique)

$workloadDisplayNames = @{
    'Detection-Remediation' = 'Detection and Remediation'
    'Custom-Compliance' = 'Custom Compliance'
    'Intune-Platform-Scripts' = 'Intune Platform Scripts'
    'Win32-Packaged-Scripts' = 'Win32 Packaged Scripts'
}

$preferredScriptInfoOrder = @(
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
    'Summary',
    'Tags'
)

$jsonReportPath = Join-Path -Path $OutputRoot -ChildPath 'detection-evidence-results.json'
$csvReportPath = Join-Path -Path $OutputRoot -ChildPath 'detection-evidence-results.csv'
$summaryReportPath = Join-Path -Path $OutputRoot -ChildPath 'detection-evidence-summary.md'

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

function Read-TextFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return ''
    }

    return [System.IO.File]::ReadAllText($Path)
}

function Add-UniqueValue {
    param(
        [System.Collections.Generic.List[string]]$List,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if (-not $List.Contains($Value)) {
        $List.Add($Value)
    }
}

function Get-ScriptFolders {
    foreach ($workloadFolderName in $workloadDisplayNames.Keys) {
        $workloadPath = Join-Path -Path $RepositoryRoot -ChildPath $workloadFolderName

        if (-not (Test-Path -LiteralPath $workloadPath -PathType Container)) {
            continue
        }

        if ($Scope -ne 'All') {
            if ($Scope -eq 'CustomCompliance' -and $workloadFolderName -ne 'Custom-Compliance') { continue }
            if ($Scope -eq 'Remediation' -and $workloadFolderName -ne 'Detection-Remediation') { continue }
            if ($Scope -eq 'Win32' -and $workloadFolderName -ne 'Win32-Packaged-Scripts') { continue }
            if ($Scope -eq 'Platform' -and $workloadFolderName -ne 'Intune-Platform-Scripts') { continue }
        }

        $purposeFolders = Get-ChildItem -LiteralPath $workloadPath -Directory | Sort-Object -Property Name
        foreach ($purposeFolder in $purposeFolders) {
            $scriptFolders = Get-ChildItem -LiteralPath $purposeFolder.FullName -Directory | Sort-Object -Property Name
            foreach ($scriptFolder in $scriptFolders) {
                $relativePackagePath = Get-RelativePath -BasePath $RepositoryRoot -Path $scriptFolder.FullName
                if (-not (Test-ValidationPackageSelected -CandidatePath $relativePackagePath -PackagePath $selectedPackagePaths)) {
                    continue
                }
                [pscustomobject]@{
                    WorkloadFolderName = $workloadFolderName
                    Workload = $workloadDisplayNames[$workloadFolderName]
                    Purpose = $purposeFolder.Name
                    Folder = $scriptFolder
                }
            }
        }
    }
}

function Get-DetectionScriptPath {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ScriptFolderInfo
    )

    switch ($ScriptFolderInfo.WorkloadFolderName) {
        'Custom-Compliance' { return (Join-Path -Path $ScriptFolderInfo.Folder.FullName -ChildPath 'Discover.ps1') }
        'Detection-Remediation' { return (Join-Path -Path $ScriptFolderInfo.Folder.FullName -ChildPath 'Detect.ps1') }
        'Win32-Packaged-Scripts' { return (Join-Path -Path $ScriptFolderInfo.Folder.FullName -ChildPath 'Detect.ps1') }
        default { return '' }
    }
}

function Get-DetectionContract {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkloadFolderName
    )

    switch ($WorkloadFolderName) {
        'Custom-Compliance' { return 'CustomComplianceDiscovery' }
        'Detection-Remediation' { return 'RemediationDetection' }
        'Win32-Packaged-Scripts' { return 'Win32Detection' }
        default { return 'None' }
    }
}

function Get-DetectionEvidenceClassification {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ScriptFolderInfo,

        [string]$DetectionScriptPath
    )

    if ([string]::IsNullOrWhiteSpace($DetectionScriptPath) -or -not (Test-Path -LiteralPath $DetectionScriptPath -PathType Leaf)) {
        return [pscustomobject]@{
            DetectionEvidenceType = 'N/A'
            DetectionEvidenceSource = 'No detection script for this workload'
            DetectionReviewStatus = 'NotApplicable'
            Reason = 'This workload does not use a detection/discovery script contract.'
        }
    }

    $content = Read-TextFile -Path $DetectionScriptPath
    $sources = New-Object System.Collections.Generic.List[string]

    $usesMarker = ($content -match '(?i)\b(ManagedState|MarkerRoot|MarkerFileName|ExpectedMarkerValue|ExpectedState)\b')
    $usesPackageMarker = (
        $ScriptFolderInfo.WorkloadFolderName -eq 'Win32-Packaged-Scripts' -and
        $content -match '(?i)\b(ExpectedPackageVersion|PackageVersion|InstallRoot|Win32Packages|MarkerFileName)\b'
    )
    $usesSnapshotFreshness = (
        $content -match '(?i)\b(SnapshotRoot|SnapshotFileName)\b' -and
        $content -match '(?i)\b(MaximumSnapshotAge|LastWriteTime|AgeHours|ConvertFrom-Json)\b'
    )

    if ($content -match '(?i)\b(Get-CimInstance|Get-WmiObject)\b[^\r\n]*(Win32_Battery|CIM_Battery)|\b(Win32_Battery|CIM_Battery)\b') {
        Add-UniqueValue -List $sources -Value 'Battery CIM/WMI'
    }

    if ($content -match '(?i)\b(Get-CimInstance|Get-WmiObject)\b') {
        Add-UniqueValue -List $sources -Value 'CIM/WMI'
    }

    if ($content -match '(?i)\bpowercfg(\.exe)?\b') {
        Add-UniqueValue -List $sources -Value 'powercfg'
    }

    if ($content -match '(?i)\b(Get-ItemProperty|Get-Item|Get-ChildItem)\b[^\r\n]*(HKLM:|HKCU:|Registry::|Cert:\\)|\b(HKLM:|HKCU:|Registry::)') {
        Add-UniqueValue -List $sources -Value 'Registry'
    }

    if ($content -match '(?i)\bGet-Acl\b') {
        Add-UniqueValue -List $sources -Value 'File system ACL'
    }

    if ($content -match '(?i)\bGet-ChildItem\b' -and
        $content -match '(?i)\bMaximum(Cache|RecycleBin)ItemsToScan\b') {
        Add-UniqueValue -List $sources -Value 'File system cache'
    }

    if ($content -match '(?i)\$env:COMPUTERNAME\b' -and
        $content -match '(?i)\bAllowedComputerNamePrefixes\b') {
        Add-UniqueValue -List $sources -Value 'Device identity'
    }

    if ($content -match '(?i)\b(Get-Service|Win32_Service)\b|\bGet-CimInstance\b[^\r\n]*Win32_Service') {
        Add-UniqueValue -List $sources -Value 'Service'
    }

    if ($content -match '(?i)\b(Get-ScheduledTask|Get-ScheduledTaskInfo)\b') {
        Add-UniqueValue -List $sources -Value 'Scheduled task'
    }

    if ($content -match '(?i)\b(Get-WinEvent|Get-EventLog)\b') {
        Add-UniqueValue -List $sources -Value 'Event log'
    }

    if ($content -match '(?i)\b(Get-BitLockerVolume|manage-bde)\b') {
        Add-UniqueValue -List $sources -Value 'BitLocker'
    }

    if ($content -match '(?i)\b(Get-TimeZone|tzutil)\b') {
        Add-UniqueValue -List $sources -Value 'Time zone'
    }

    if ($content -match '(?i)\b(Get-LocalGroupMember|Get-LocalUser|Get-LocalGroup)\b|SecurityIdentifier\(') {
        Add-UniqueValue -List $sources -Value 'Local accounts/groups'
    }

    if ($content -match '(?i)\b(Win32_OperatingSystem|Get-ComputerInfo)\b|\[System\.Environment\]::OSVersion|\[Environment\]::OSVersion') {
        Add-UniqueValue -List $sources -Value 'Operating system'
    }

    if ($content -match '(?i)\b(Win32_LogicalDisk|Get-Volume|Get-PSDrive|Get-PhysicalDisk|Get-Partition|Get-StorageReliabilityCounter)\b') {
        Add-UniqueValue -List $sources -Value 'Storage'
    }

    if ($content -match '(?i)\b(Get-MpComputerStatus|Get-MpPreference|Get-MpThreatDetection)\b') {
        Add-UniqueValue -List $sources -Value 'Defender'
    }

    if ($content -match '(?i)\b(Get-Tpm|Confirm-SecureBootUEFI)\b') {
        Add-UniqueValue -List $sources -Value 'Security hardware'
    }

    if ($content -match '(?i)\b(dsregcmd|reagentc|slmgr|cscript\.exe|certutil)\b') {
        Add-UniqueValue -List $sources -Value 'Windows command evidence'
    }

    if ($content -match '(?i)\b(Get-NetAdapter|Get-NetIPConfiguration|Get-NetFirewallRule|Get-NetConnectionProfile|Get-DnsClient|netsh)\b') {
        Add-UniqueValue -List $sources -Value 'Network configuration'
    }

    if ($content -match '(?i)\b(Get-AppxPackage|Get-Package|Win32_Product)\b|\\CurrentVersion\\Uninstall\\|DisplayName') {
        Add-UniqueValue -List $sources -Value 'Application inventory'
    }

    if ($content -match '(?i)\b(Get-Printer|Get-PrinterDriver|Get-PrinterPort|Get-PrintConfiguration|Get-PrintProcessor)\b') {
        Add-UniqueValue -List $sources -Value 'Printing'
    }

    if ($content -match '(?i)\b(Get-PnpDevice|Get-PnpDeviceProperty)\b') {
        Add-UniqueValue -List $sources -Value 'Plug and Play'
    }

    if ($content -match '(?i)\b(Cert:\\|X509Store|Get-PfxCertificate|Get-ChildItem\b[^\r\n]*Cert:)\b') {
        Add-UniqueValue -List $sources -Value 'Certificate store'
    }

    if ($usesSnapshotFreshness) {
        return [pscustomobject]@{
            DetectionEvidenceType = 'SnapshotFreshness'
            DetectionEvidenceSource = 'Snapshot file age/freshness'
            DetectionReviewStatus = 'Reviewed'
            Reason = 'The script checks whether a snapshot exists and is fresh enough for remediation targeting.'
        }
    }

    if ($sources.Count -gt 0) {
        return [pscustomobject]@{
            DetectionEvidenceType = 'DirectEvidence'
            DetectionEvidenceSource = ($sources.ToArray() -join '; ')
            DetectionReviewStatus = 'Reviewed'
            Reason = 'The script reads recognized device state directly.'
        }
    }

    if ($usesPackageMarker) {
        return [pscustomobject]@{
            DetectionEvidenceType = 'PackageMarker'
            DetectionEvidenceSource = 'Win32 package install/version marker'
            DetectionReviewStatus = 'Reviewed'
            Reason = 'Win32 app detection may use an install marker when the package owns the marker.'
        }
    }

    if ($usesMarker) {
        return [pscustomobject]@{
            DetectionEvidenceType = 'MarkerOnly'
            DetectionEvidenceSource = 'Managed state marker file only'
            DetectionReviewStatus = 'NeedsReview'
            Reason = 'The script checks repository-managed marker state without recognized direct device evidence.'
        }
    }

    return [pscustomobject]@{
        DetectionEvidenceType = 'NeedsReview'
        DetectionEvidenceSource = 'No recognized direct evidence source'
        DetectionReviewStatus = 'NeedsReview'
        Reason = 'The audit did not recognize a direct evidence source or an acceptable package marker pattern.'
    }
}

function Read-ScriptInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-ScriptInfoValue {
    param(
        [AllowNull()]
        [object]$ScriptInfo,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $ScriptInfo) {
        return ''
    }

    if ($ScriptInfo.PSObject.Properties.Name -contains $Name) {
        return [string]$ScriptInfo.$Name
    }

    return ''
}

function ConvertTo-OrderedScriptInfo {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$ScriptInfo,

        [Parameter(Mandatory = $true)]
        [object]$AuditResult
    )

    $ordered = [ordered]@{}

    foreach ($propertyName in $preferredScriptInfoOrder) {
        switch ($propertyName) {
            'DetectionEvidenceType' { $ordered[$propertyName] = $AuditResult.DetectionEvidenceType }
            'DetectionEvidenceSource' { $ordered[$propertyName] = $AuditResult.DetectionEvidenceSource }
            'DetectionReviewStatus' { $ordered[$propertyName] = $AuditResult.DetectionReviewStatus }
            default {
                if ($ScriptInfo.PSObject.Properties.Name -contains $propertyName) {
                    $ordered[$propertyName] = $ScriptInfo.$propertyName
                }
            }
        }
    }

    foreach ($property in $ScriptInfo.PSObject.Properties) {
        if (-not $ordered.Contains($property.Name)) {
            $ordered[$property.Name] = $property.Value
        }
    }

    return $ordered
}

function Update-ScriptInfoEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [object]$AuditResult
    )

    $scriptInfo = Read-ScriptInfo -Path $AuditResult.ScriptInfoPath
    if ($null -eq $scriptInfo) {
        return
    }

    $ordered = ConvertTo-OrderedScriptInfo -ScriptInfo $scriptInfo -AuditResult $AuditResult
    $json = $ordered | ConvertTo-Json -Depth 10
    Set-Content -LiteralPath $AuditResult.ScriptInfoPath -Value ($json + [Environment]::NewLine) -Encoding UTF8 -NoNewline
}

function New-AuditResult {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ScriptFolderInfo
    )

    $scriptInfoPath = Join-Path -Path $ScriptFolderInfo.Folder.FullName -ChildPath 'ScriptInfo.json'
    $detectionScriptPath = Get-DetectionScriptPath -ScriptFolderInfo $ScriptFolderInfo
    $classification = Get-DetectionEvidenceClassification -ScriptFolderInfo $ScriptFolderInfo -DetectionScriptPath $detectionScriptPath
    $scriptInfo = Read-ScriptInfo -Path $scriptInfoPath

    $metadataEvidenceType = Get-ScriptInfoValue -ScriptInfo $scriptInfo -Name 'DetectionEvidenceType'
    $metadataEvidenceSource = Get-ScriptInfoValue -ScriptInfo $scriptInfo -Name 'DetectionEvidenceSource'
    $metadataReviewStatus = Get-ScriptInfoValue -ScriptInfo $scriptInfo -Name 'DetectionReviewStatus'

    $metadataCurrent = (
        $metadataEvidenceType -eq $classification.DetectionEvidenceType -and
        $metadataEvidenceSource -eq $classification.DetectionEvidenceSource -and
        $metadataReviewStatus -eq $classification.DetectionReviewStatus
    )

    [pscustomobject]@{
        Workload = $ScriptFolderInfo.Workload
        Purpose = $ScriptFolderInfo.Purpose
        PackageName = $ScriptFolderInfo.Folder.Name
        PackagePath = Get-RelativePath -BasePath $RepositoryRoot -Path $ScriptFolderInfo.Folder.FullName
        DetectionContract = Get-DetectionContract -WorkloadFolderName $ScriptFolderInfo.WorkloadFolderName
        DetectionScriptPath = $detectionScriptPath
        DetectionScriptRelativePath = if ([string]::IsNullOrWhiteSpace($detectionScriptPath)) { '' } else { Get-RelativePath -BasePath $RepositoryRoot -Path $detectionScriptPath }
        ScriptInfoPath = $scriptInfoPath
        ScriptInfoRelativePath = Get-RelativePath -BasePath $RepositoryRoot -Path $scriptInfoPath
        DetectionEvidenceType = $classification.DetectionEvidenceType
        DetectionEvidenceSource = $classification.DetectionEvidenceSource
        DetectionReviewStatus = $classification.DetectionReviewStatus
        Reason = $classification.Reason
        MetadataEvidenceType = $metadataEvidenceType
        MetadataEvidenceSource = $metadataEvidenceSource
        MetadataReviewStatus = $metadataReviewStatus
        MetadataCurrent = $metadataCurrent
    }
}

function New-CsvRows {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Results
    )

    foreach ($result in $Results) {
        [pscustomobject]@{
            Workload = $result.Workload
            Purpose = $result.Purpose
            PackageName = $result.PackageName
            PackagePath = $result.PackagePath
            DetectionContract = $result.DetectionContract
            DetectionScript = $result.DetectionScriptRelativePath
            DetectionEvidenceType = $result.DetectionEvidenceType
            DetectionEvidenceSource = $result.DetectionEvidenceSource
            DetectionReviewStatus = $result.DetectionReviewStatus
            MetadataCurrent = $result.MetadataCurrent
            Reason = $result.Reason
        }
    }
}

function Add-MarkdownCountTable {
    param(
        [System.Collections.Generic.List[string]]$Lines,

        [Parameter(Mandatory = $true)]
        [array]$Rows,

        [Parameter(Mandatory = $true)]
        [string]$FirstHeader
    )

    $Lines.Add("| $FirstHeader | Count |")
    $Lines.Add('| --- | ---: |')

    foreach ($row in $Rows) {
        $Lines.Add("| $($row.Name) | $($row.Count) |")
    }
}

function Write-SummaryReport {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Results,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $needsReview = @($Results | Where-Object { $_.DetectionReviewStatus -eq 'NeedsReview' })
    $staleMetadata = @($Results | Where-Object { -not $_.MetadataCurrent })

    $lines.Add('# Detection Evidence Audit Summary')
    $lines.Add('')
    $lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $lines.Add('')
    $lines.Add('## Run Settings')
    $lines.Add('')
    $lines.Add('| Setting | Value |')
    $lines.Add('| --- | --- |')
    $lines.Add("| Scope | $Scope |")
    $lines.Add("| UpdateScriptInfo | $([bool]$UpdateScriptInfo) |")
    $lines.Add("| Check | $([bool]$Check) |")
    $lines.Add("| FailOnNeedsReview | $([bool]$FailOnNeedsReview) |")
    $lines.Add('')
    $lines.Add('## Results')
    $lines.Add('')
    $lines.Add('| Metric | Count |')
    $lines.Add('| --- | ---: |')
    $lines.Add("| Packages audited | $($Results.Count) |")
    $lines.Add("| Needs review | $($needsReview.Count) |")
    $lines.Add("| Metadata not current | $($staleMetadata.Count) |")
    $lines.Add('')
    $lines.Add('## By Evidence Type')
    $lines.Add('')
    Add-MarkdownCountTable -Lines $lines -Rows @($Results | Group-Object -Property DetectionEvidenceType | Sort-Object Name) -FirstHeader 'Evidence Type'
    $lines.Add('')
    $lines.Add('## By Review Status')
    $lines.Add('')
    Add-MarkdownCountTable -Lines $lines -Rows @($Results | Group-Object -Property DetectionReviewStatus | Sort-Object Name) -FirstHeader 'Review Status'
    $lines.Add('')

    if ($needsReview.Count -gt 0) {
        $lines.Add('## Needs Review')
        $lines.Add('')
        $lines.Add('| Package | Type | Source | Reason |')
        $lines.Add('| --- | --- | --- | --- |')

        foreach ($result in @($needsReview | Select-Object -First 100)) {
            $packagePath = $result.PackagePath -replace '\|', '/'
            $source = $result.DetectionEvidenceSource -replace '\|', '/'
            $reason = $result.Reason -replace '\|', '/'
            $lines.Add("| ``$packagePath`` | $($result.DetectionEvidenceType) | $source | $reason |")
        }

        if ($needsReview.Count -gt 100) {
            $lines.Add('')
            $lines.Add("Only the first 100 needs-review packages are shown. See $csvReportPath for the full list.")
        }

        $lines.Add('')
    }

    if ($staleMetadata.Count -gt 0) {
        $lines.Add('## Metadata Not Current')
        $lines.Add('')
        $lines.Add('| ScriptInfo | Expected Type | Current Type |')
        $lines.Add('| --- | --- | --- |')

        foreach ($result in @($staleMetadata | Select-Object -First 100)) {
            $scriptInfoPath = $result.ScriptInfoRelativePath -replace '\|', '/'
            $lines.Add("| ``$scriptInfoPath`` | $($result.DetectionEvidenceType) | $($result.MetadataEvidenceType) |")
        }

        if ($staleMetadata.Count -gt 100) {
            $lines.Add('')
            $lines.Add("Only the first 100 stale metadata entries are shown. See $csvReportPath for the full list.")
        }

        $lines.Add('')
    }

    $lines.Add('## Notes')
    $lines.Add('')
    $lines.Add('- `DirectEvidence` means the script reads a recognized device source such as CIM/WMI, registry, service state, event logs, powercfg, OS/storage state, local groups, certificates, BitLocker, or application inventory.')
    $lines.Add('- `SnapshotFreshness` means the script validates an existing snapshot file and its age.')
    $lines.Add('- `PackageMarker` is acceptable for Win32 app detection when the package install script owns the marker.')
    $lines.Add('- `MarkerOnly` and `NeedsReview` should not be presented as direct device-state compliance without additional review or rewritten checks.')

    Set-Content -LiteralPath $Path -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
}

if ($Check -and $UpdateScriptInfo) {
    throw 'Use either -Check or -UpdateScriptInfo, not both.'
}

if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
    New-Item -Path $OutputRoot -ItemType Directory -Force | Out-Null
}

$results = @(Get-ScriptFolders | ForEach-Object { New-AuditResult -ScriptFolderInfo $_ })

if ($UpdateScriptInfo) {
    foreach ($result in $results) {
        Update-ScriptInfoEvidence -AuditResult $result
    }

    $results = @(Get-ScriptFolders | ForEach-Object { New-AuditResult -ScriptFolderInfo $_ })
}

$results | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonReportPath -Encoding UTF8
New-CsvRows -Results $results | Export-Csv -LiteralPath $csvReportPath -NoTypeInformation -Encoding UTF8
Write-SummaryReport -Results $results -Path $summaryReportPath

$needsReviewCount = @($results | Where-Object { $_.DetectionReviewStatus -eq 'NeedsReview' }).Count
$staleMetadataCount = @($results | Where-Object { -not $_.MetadataCurrent }).Count

if (-not $SummaryOnly) {
    Write-Output "Detection evidence audit report written to '$summaryReportPath'."
}
Write-Output "Packages: $($results.Count); NeedsReview: $needsReviewCount; MetadataNotCurrent: $staleMetadataCount."

if (-not [string]::IsNullOrWhiteSpace($ResultPath)) {
    $ruleResults = New-Object System.Collections.Generic.List[object]
    foreach ($result in $results) {
        if (-not $result.MetadataCurrent) {
            $severity = if ($Check) { 'Failure' } else { 'Warning' }
            $ruleResults.Add((New-ValidationRuleResult -RuleId 'DetectionEvidence.MetadataCurrent' -Severity $severity -Message 'Detection evidence metadata does not match the current classification.' -PackagePath $result.PackagePath -File $result.ScriptInfoPath))
        }
        if ($result.DetectionReviewStatus -eq 'NeedsReview') {
            $severity = if ($FailOnNeedsReview) { 'Failure' } else { 'Warning' }
            $ruleResults.Add((New-ValidationRuleResult -RuleId 'DetectionEvidence.NeedsReview' -Severity $severity -Message ([string]$result.Reason) -PackagePath $result.PackagePath -File $result.DetectionScriptPath))
        }
    }
    if ($ruleResults.Count -eq 0) {
        $ruleResults.Add((New-ValidationRuleResult -RuleId 'DetectionEvidence.Current' -Severity Pass -Message "Detection evidence metadata is current for $($results.Count) selected packages."))
    }
    $structuredFailures = @($ruleResults | Where-Object Severity -eq 'Failure').Count
    $structuredWarnings = @($ruleResults | Where-Object Severity -eq 'Warning').Count
    $structured = [ordered]@{
        Validator = 'DetectionEvidence'
        PackageCount = $results.Count
        Counts = [ordered]@{ Pass = $(if ($structuredFailures -eq 0) { 1 } else { 0 }); Warning = $structuredWarnings; Failure = $structuredFailures }
        Results = @($ruleResults.ToArray())
    }
    Write-ValidationResultFile -Path $ResultPath -InputObject $structured
}

if ($Check -and $staleMetadataCount -gt 0) {
    Write-Output 'Detection evidence metadata is not current. Run tools\Test-DetectionEvidence.ps1 -UpdateScriptInfo and commit the result.'
    exit 1
}

if ($FailOnNeedsReview -and $needsReviewCount -gt 0) {
    Write-Output 'One or more detection scripts still need evidence review.'
    exit 1
}

exit 0
