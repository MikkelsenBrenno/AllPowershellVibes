<#
.SYNOPSIS
    Creates a new Intune script folder from repository conventions.

.DESCRIPTION
    Helper for maintainers who want a correctly named folder and starter
    README. This script does not overwrite existing folders.

    Use -IncludeTeamsAlertBlock when the generated script should include the
    optional Teams failure alerting block. The block is added only to action
    scripts where alerting is normally appropriate.

.NOTES
    Name:        New-IntuneScriptFolder.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     Local maintainer
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Category')]
    [ValidateSet('Detection-Remediation', 'Custom-Compliance', 'Intune-Platform-Scripts', 'Win32-Packaged-Scripts')]
    [string]$Workload,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Security', 'Compliance', 'Device-Configuration', 'Applications', 'Maintenance', 'Endpoint-Health', 'Networking', 'User-Experience', 'Inventory-Reporting', 'Windows-Updates', 'Browser-Management', 'Remote-Work', 'Identity-Access', 'Printing', 'Certificates-PKI', 'Hardware-Drivers', 'Power-Battery', 'Backup-Recovery', 'MDM-Enrollment', 'Data-Protection', 'Storage-Disk', 'Troubleshooting-Support', 'Peripheral-Devices', 'Licensing-Activation')]
    [string]$ScriptCategory,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9]+(-[A-Za-z0-9]+)*$')]
    [string]$Name,

    [string]$RepositoryRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path,

    [string]$Summary = '',

    [ValidateSet('System', 'User')]
    [string]$Context = 'System',

    [switch]$Requires64Bit,

    [ValidateSet('Template', 'Planned', 'Example', 'NeedsReview')]
    [string]$Status = 'Template',

    [string]$WritesTo = '',

    [string]$Reboot = 'No',

    [ValidateSet('Low', 'Medium', 'High')]
    [string]$Risk = 'Medium',

    [string[]]$Tags = @(),

    [switch]$IncludeTeamsAlertBlock
)

$ErrorActionPreference = 'Stop'

$workloadPath = Join-Path -Path $RepositoryRoot -ChildPath $Workload
$scriptCategoryPath = Join-Path -Path $workloadPath -ChildPath $ScriptCategory
$targetPath = Join-Path -Path $scriptCategoryPath -ChildPath $Name

if (-not (Test-Path -LiteralPath $workloadPath -PathType Container)) {
    throw "Workload folder '$workloadPath' does not exist."
}

if (-not (Test-Path -LiteralPath $scriptCategoryPath -PathType Container)) {
    throw "Purpose category folder '$scriptCategoryPath' does not exist."
}

if (Test-Path -LiteralPath $targetPath) {
    throw "Target folder '$targetPath' already exists."
}

New-Item -Path $targetPath -ItemType Directory -Force | Out-Null

function Set-ScriptIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$ScriptFileBaseName
    )

    $content = Get-Content -LiteralPath $Path -Raw
    $scriptDisplayName = "$ScriptFileBaseName.ps1"
    $createdDate = Get-Date -Format 'yyyy-MM-dd'

    if ([string]::IsNullOrWhiteSpace($Summary)) {
        $shortDescription = '<Short description of what this script does.>'
        $longDescription = '<Longer description of the intended Intune use case.>'
    }
    else {
        $shortDescription = $Summary
        $longDescription = $Summary
    }

    $content = $content.Replace('<Short description of what this script does.>', $shortDescription)
    $content = $content.Replace('<Longer description of the intended Intune use case.>', $longDescription)
    $content = $content.Replace('Name:        <ScriptName.ps1>', "Name:        $scriptDisplayName")
    $content = $content.Replace('Author:      <Author or team>', 'Author:      <Author or team>')
    $content = $content.Replace('Created:     <YYYY-MM-DD>', "Created:     $createdDate")
    $content = $content.Replace('Updated:     <YYYY-MM-DD>', "Updated:     $createdDate")
    $content = $content.Replace('Context:     <System or User>', "Context:     $Context")
    $workloadDisplayName = Get-WorkloadDisplayName -WorkloadFolderName $Workload
    $content = $content.Replace('Workload:    <Remediation | Custom Compliance | Platform Script | Win32 App>', "Workload:    $workloadDisplayName")
    $content = $content.Replace('$ScriptPackageName = ''<Script-Folder-Name>''', "`$ScriptPackageName = '$Name'")
    $content = $content.Replace('$ScriptName = ''<ScriptName>''', "`$ScriptName = '$ScriptFileBaseName'")
    Set-Content -Path $Path -Value $content -Encoding UTF8
}

function Set-ReadmePlaceholders {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$PrimaryScriptFileName
    )

    $content = Get-Content -LiteralPath $Path -Raw

    if ([string]::IsNullOrWhiteSpace($Summary)) {
        $summaryText = '<Describe what this script package does.>'
    }
    else {
        $summaryText = $Summary
    }

    if ($Context -eq 'User') {
        $loggedOnCredentialSetting = 'Yes'
    }
    else {
        $loggedOnCredentialSetting = 'No'
    }

    if ($Requires64Bit) {
        $requires64BitSetting = 'Yes'
        $runDetection32BitSetting = 'No'
    }
    else {
        $requires64BitSetting = 'No unless this script uses native HKLM or System32 paths'
        $runDetection32BitSetting = 'No when using native HKLM or Program Files paths'
    }

    $content = $content.Replace('<Script Name>', $Name)
    $content = $content.Replace('<Platform Script Name>', $Name)
    $content = $content.Replace('<Custom Compliance Script Name>', $Name)
    $content = $content.Replace('<Win32 Packaged Script Name>', $Name)
    $content = $content.Replace('Describe what the detection script checks and what the remediation script changes.', $summaryText)
    $content = $content.Replace('Describe what the script configures on Windows devices.', $summaryText)
    $content = $content.Replace('Describe the custom compliance setting discovered by the PowerShell script and evaluated by the JSON rule file.', $summaryText)
    $content = $content.Replace('Describe what the packaged PowerShell script installs, uninstalls, and detects.', $summaryText)
    $content = $content.Replace('<ScriptName>.ps1', $PrimaryScriptFileName)
    $content = $content.Replace('<Yes or No>', $loggedOnCredentialSetting)
    $content = $content.Replace('<System or User>', $Context)
    $content = $content.Replace('<Yes when using native HKLM or System32 paths>', $requires64BitSetting)
    $content = $content.Replace('<No when using native HKLM or Program Files paths>', $runDetection32BitSetting)
    Set-Content -Path $Path -Value $content -Encoding UTF8
}

function Add-TeamsAlertBlock {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $templatePath = Join-Path -Path $RepositoryRoot -ChildPath 'templates\TeamsFailureAlert.Template.ps1'

    if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
        throw "Teams alert template '$templatePath' does not exist."
    }

    $content = Get-Content -LiteralPath $Path -Raw
    $teamsAlertBlock = Get-Content -LiteralPath $templatePath -Raw
    $mainMarkerPattern = '(?m)^# =========================\r?\n# MAIN\r?\n# ========================='

    if ($content -match $mainMarkerPattern) {
        $updatedContent = [regex]::Replace(
            $content,
            $mainMarkerPattern,
            ($teamsAlertBlock.Trim() + "`r`n`r`n" + '$0'),
            1
        )
    }
    else {
        $updatedContent = $content.TrimEnd() + "`r`n`r`n" + $teamsAlertBlock.Trim() + "`r`n"
    }

    Set-Content -Path $Path -Value $updatedContent -Encoding UTF8
}

function Get-WorkloadDisplayName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkloadFolderName
    )

    switch ($WorkloadFolderName) {
        'Detection-Remediation' { return 'Detection and Remediation' }
        'Custom-Compliance' { return 'Custom Compliance' }
        'Intune-Platform-Scripts' { return 'Intune Platform Scripts' }
        'Win32-Packaged-Scripts' { return 'Win32 Packaged Scripts' }
    }
}

function New-ScriptInfoFile {
    $scriptInfoPath = Join-Path -Path $targetPath -ChildPath 'ScriptInfo.json'
    $workloadDisplayName = Get-WorkloadDisplayName -WorkloadFolderName $Workload
    $displayName = ($Name -replace '-', ' ')
    $metadataSummary = if ([string]::IsNullOrWhiteSpace($Summary)) { '<One-sentence purpose>' } else { $Summary }
    $metadataWritesTo = if ([string]::IsNullOrWhiteSpace($WritesTo)) {
        switch ($Workload) {
            'Custom-Compliance' { 'Compressed JSON to STDOUT; local diagnostic logs only' }
            'Detection-Remediation' { '<What remediation changes or Logs only>' }
            'Intune-Platform-Scripts' { '<What the script changes>' }
            'Win32-Packaged-Scripts' { '<What install/uninstall changes>' }
        }
    }
    else {
        $WritesTo
    }

    $hasRemediation = if ($Workload -eq 'Detection-Remediation') { 'Yes' } elseif ($Workload -eq 'Intune-Platform-Scripts' -or $Workload -eq 'Win32-Packaged-Scripts') { 'N/A' } else { 'No' }
    $hasUninstall = if ($Workload -eq 'Win32-Packaged-Scripts') { 'Yes' } else { 'No' }
    $teamsAlertReady = if ($IncludeTeamsAlertBlock) { 'Yes' } else { 'No' }
    $requires64BitValue = if ($Requires64Bit) { 'Required' } else { 'Recommended' }
    $metadataTags = @($ScriptCategory, $Workload) + $Tags

    if ($Workload -eq 'Intune-Platform-Scripts') {
        $detectionEvidenceType = 'N/A'
        $detectionEvidenceSource = 'No detection script for this workload'
        $detectionReviewStatus = 'NotApplicable'
    }
    else {
        $detectionEvidenceType = 'NeedsReview'
        $detectionEvidenceSource = 'Generated package has not been evidence-audited'
        $detectionReviewStatus = 'NeedsReview'
    }

    $portabilityRiskAreas = @(
        'Localization',
        'OsVersion',
        'CommandParsing',
        'Scalability',
        'RegistryView',
        'PathAssumption'
    )

    $metadata = [ordered]@{
        Name = $displayName
        Workload = $workloadDisplayName
        Purpose = $ScriptCategory
        Status = $Status
        Context = $Context
        Requires64BitPowerShell = $requires64BitValue
        HasRemediation = $hasRemediation
        HasUninstall = $hasUninstall
        TeamsAlertReady = $teamsAlertReady
        WritesTo = $metadataWritesTo
        Reboot = $Reboot
        Risk = $Risk
        DetectionEvidenceType = $detectionEvidenceType
        DetectionEvidenceSource = $detectionEvidenceSource
        DetectionReviewStatus = $detectionReviewStatus
        PortabilityReviewStatus = 'NeedsReview'
        PortabilityRiskLevel = 'Medium'
        PortabilityRiskAreas = $portabilityRiskAreas
        PortabilityNotes = 'Generated package has not been portability-audited'
        Summary = $metadataSummary
        Tags = $metadataTags
    }

    $metadata | ConvertTo-Json -Depth 8 | Set-Content -Path $scriptInfoPath -Encoding UTF8
}

switch ($Workload) {
    'Detection-Remediation' {
        $detectPath = Join-Path -Path $targetPath -ChildPath 'Detect.ps1'
        $remediatePath = Join-Path -Path $targetPath -ChildPath 'Remediate.ps1'
        Copy-Item -LiteralPath (Join-Path -Path $RepositoryRoot -ChildPath 'templates\RemediationDetection.Template.ps1') -Destination $detectPath
        Copy-Item -LiteralPath (Join-Path -Path $RepositoryRoot -ChildPath 'templates\RemediationAction.Template.ps1') -Destination $remediatePath
        Set-ScriptIdentity -Path $detectPath -ScriptFileBaseName 'Detect'
        Set-ScriptIdentity -Path $remediatePath -ScriptFileBaseName 'Remediate'
        if ($IncludeTeamsAlertBlock) {
            Add-TeamsAlertBlock -Path $remediatePath
        }
        $readmePath = Join-Path -Path $targetPath -ChildPath 'README.md'
        Copy-Item -LiteralPath (Join-Path -Path $RepositoryRoot -ChildPath 'templates\DetectionRemediation.README.Template.md') -Destination $readmePath
        Set-ReadmePlaceholders -Path $readmePath -PrimaryScriptFileName 'Detect.ps1'
    }
    'Custom-Compliance' {
        $discoverPath = Join-Path -Path $targetPath -ChildPath 'Discover.ps1'
        Copy-Item -LiteralPath (Join-Path -Path $RepositoryRoot -ChildPath 'templates\CustomComplianceDiscovery.Template.ps1') -Destination $discoverPath
        Set-ScriptIdentity -Path $discoverPath -ScriptFileBaseName 'Discover'
        $readmePath = Join-Path -Path $targetPath -ChildPath 'README.md'
        Copy-Item -LiteralPath (Join-Path -Path $RepositoryRoot -ChildPath 'templates\CustomCompliance.README.Template.md') -Destination $readmePath
        Set-ReadmePlaceholders -Path $readmePath -PrimaryScriptFileName 'Discover.ps1'

        $json = [ordered]@{
            Rules = @(
                [ordered]@{
                    SettingName = 'ExampleSetting'
                    Operator = 'IsEquals'
                    DataType = 'String'
                    Operand = '<Expected value>'
                    MoreInfoUrl = 'https://learn.microsoft.com/en-us/intune/device-security/compliance/create-custom-json'
                    RemediationStrings = @(
                        [ordered]@{
                            Language = 'en_US'
                            Title = 'The required setting is not compliant. Current value: {ActualValue}.'
                            Description = 'Contact your support team or follow the linked guidance to restore compliance.'
                        }
                    )
                }
            )
        } | ConvertTo-Json -Depth 8

        Set-Content -Path (Join-Path -Path $targetPath -ChildPath 'ComplianceRules.json') -Value $json -Encoding UTF8
    }
    'Intune-Platform-Scripts' {
        $scriptPath = Join-Path -Path $targetPath -ChildPath "$Name.ps1"
        Copy-Item -LiteralPath (Join-Path -Path $RepositoryRoot -ChildPath 'templates\PlatformScriptAction.Template.ps1') -Destination $scriptPath
        Set-ScriptIdentity -Path $scriptPath -ScriptFileBaseName $Name
        if ($IncludeTeamsAlertBlock) {
            Add-TeamsAlertBlock -Path $scriptPath
        }
        $readmePath = Join-Path -Path $targetPath -ChildPath 'README.md'
        Copy-Item -LiteralPath (Join-Path -Path $RepositoryRoot -ChildPath 'templates\PlatformScript.README.Template.md') -Destination $readmePath
        Set-ReadmePlaceholders -Path $readmePath -PrimaryScriptFileName "$Name.ps1"
    }
    'Win32-Packaged-Scripts' {
        $installPath = Join-Path -Path $targetPath -ChildPath 'Install.ps1'
        $uninstallPath = Join-Path -Path $targetPath -ChildPath 'Uninstall.ps1'
        $detectPath = Join-Path -Path $targetPath -ChildPath 'Detect.ps1'
        Copy-Item -LiteralPath (Join-Path -Path $RepositoryRoot -ChildPath 'templates\ScriptHeader.Template.ps1') -Destination $installPath
        Copy-Item -LiteralPath (Join-Path -Path $RepositoryRoot -ChildPath 'templates\ScriptHeader.Template.ps1') -Destination $uninstallPath
        Copy-Item -LiteralPath (Join-Path -Path $RepositoryRoot -ChildPath 'templates\ScriptHeader.Template.ps1') -Destination $detectPath
        Set-ScriptIdentity -Path $installPath -ScriptFileBaseName 'Install'
        Set-ScriptIdentity -Path $uninstallPath -ScriptFileBaseName 'Uninstall'
        Set-ScriptIdentity -Path $detectPath -ScriptFileBaseName 'Detect'
        if ($IncludeTeamsAlertBlock) {
            Add-TeamsAlertBlock -Path $installPath
            Add-TeamsAlertBlock -Path $uninstallPath
        }
        $readmePath = Join-Path -Path $targetPath -ChildPath 'README.md'
        Copy-Item -LiteralPath (Join-Path -Path $RepositoryRoot -ChildPath 'templates\Win32Package.README.Template.md') -Destination $readmePath
        Set-ReadmePlaceholders -Path $readmePath -PrimaryScriptFileName 'Install.ps1'
    }
}

New-ScriptInfoFile
Write-Output "Created '$targetPath'."

if ($IncludeTeamsAlertBlock) {
    Write-Output 'Teams failure alert block was added to supported action scripts. Detection and discovery scripts were left clean by design.'
}

if (-not [string]::IsNullOrWhiteSpace($Summary)) {
    Write-Output "Summary applied: $Summary"
}

Write-Output "Default context: $Context."
Write-Output "Package status: $Status. Generated workload scaffolds must pass tools\Test-IntuneWorkloadContracts.ps1 before promotion to PilotReady."

if ($Requires64Bit) {
    Write-Output '64-bit PowerShell guidance was prefilled as required.'
}
