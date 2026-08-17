<#
.SYNOPSIS
    Validates repository packages against Microsoft Intune workload contracts.

.DESCRIPTION
    Checks package shape, workload metadata, Custom Compliance JSON rules, and
    strict promotion gates for packages marked PilotReady or Validated.

    Experimental packages remain reportable as warnings. A package cannot be
    promoted while it contains unfinished workload logic, marker-only evidence,
    unreviewed evidence, or workload-specific contract violations.

.NOTES
    Name:        Test-IntuneWorkloadContracts.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     Local maintainer and CI

    Contract:    docs\Intune-Workload-Contracts.md
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path,

    [ValidateRange(0, 500)]
    [int]$MaximumDetails = 40
)

$ErrorActionPreference = 'Stop'

$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$packageCount = 0
$readyCount = 0

$validStatuses = @(
    'Template',
    'Planned',
    'Example',
    'NeedsReview',
    'PilotReady',
    'Validated'
)

$readyStatuses = @('PilotReady', 'Validated')
$validComplianceOperators = @('IsEquals', 'NotEquals', 'GreaterThan', 'GreaterEquals', 'LessThan', 'LessEquals')
$validComplianceDataTypes = @('Boolean', 'Int64', 'Double', 'String', 'DateTime', 'Version')

$workloads = @(
    [pscustomobject]@{
        Folder = 'Detection-Remediation'
        DisplayName = 'Detection and Remediation'
        Contract = 'Remediation'
    },
    [pscustomobject]@{
        Folder = 'Custom-Compliance'
        DisplayName = 'Custom Compliance'
        Contract = 'CustomCompliance'
    },
    [pscustomobject]@{
        Folder = 'Intune-Platform-Scripts'
        DisplayName = 'Intune Platform Scripts'
        Contract = 'Platform'
    }
)

function Add-Failure {
    param([Parameter(Mandatory = $true)][string]$Message)
    $failures.Add($Message)
}

function Add-Warning {
    param([Parameter(Mandatory = $true)][string]$Message)
    $warnings.Add($Message)
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $baseUri = New-Object System.Uri(($BasePath.TrimEnd('\') + '\'))
    $pathUri = New-Object System.Uri($Path)
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('/', '\')
}

function Test-RequiredFile {
    param(
        [Parameter(Mandatory = $true)][string]$PackagePath,
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][string]$RelativePackagePath
    )

    $path = Join-Path -Path $PackagePath -ChildPath $FileName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Failure -Message "$RelativePackagePath is missing required workload file '$FileName'."
        return $false
    }

    return $true
}

function Test-ForbiddenFile {
    param(
        [Parameter(Mandatory = $true)][string]$PackagePath,
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][string]$RelativePackagePath
    )

    $path = Join-Path -Path $PackagePath -ChildPath $FileName
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Add-Failure -Message "$RelativePackagePath contains '$FileName', which belongs to a different workload contract."
    }
}

function Test-ExitCodePath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RelativePackagePath,
        [Parameter(Mandatory = $true)][string]$FileName
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }

    $content = Get-Content -LiteralPath $Path -Raw
    foreach ($exitCode in @(0, 1)) {
        if ($content -notmatch "(?im)^\s*exit\s+$exitCode\b") {
            Add-Failure -Message "$RelativePackagePath\$FileName has no explicit 'exit $exitCode' path required by its repository contract."
        }
    }
}

function Test-UnfinishedLogic {
    param(
        [Parameter(Mandatory = $true)][string]$PackagePath,
        [Parameter(Mandatory = $true)][string]$RelativePackagePath,
        [Parameter(Mandatory = $true)][bool]$IsReady
    )

    $patterns = @(
        'IMPLEMENT WORKLOAD LOGIC',
        'Replace this snapshot block',
        'Replace with tenant-approved',
        'ExampleTenantDomain',
        'ExampleVpnProfileName',
        'ExamplePrinterName'
    )

    $foundPatterns = New-Object System.Collections.Generic.List[string]
    foreach ($scriptFile in @(Get-ChildItem -LiteralPath $PackagePath -Filter '*.ps1' -File)) {
        $content = Get-Content -LiteralPath $scriptFile.FullName -Raw
        foreach ($pattern in $patterns) {
            if ($content -match [regex]::Escape($pattern)) {
                $foundPatterns.Add("$($scriptFile.Name): $pattern")
            }
        }
    }

    if ($foundPatterns.Count -eq 0) {
        return
    }

    $message = "$RelativePackagePath contains unfinished or generic workload logic ($(@($foundPatterns | Select-Object -Unique) -join '; '))."
    if ($IsReady) {
        Add-Failure -Message $message
    }
    else {
        Add-Warning -Message $message
    }
}

function Test-ReadyReviewMetadata {
    param(
        [Parameter(Mandatory = $true)][object]$ScriptInfo,
        [Parameter(Mandatory = $true)][string]$RelativePackagePath,
        [Parameter(Mandatory = $true)][string]$Contract
    )

    if ($ScriptInfo.PortabilityReviewStatus -ne 'Reviewed') {
        Add-Failure -Message "$RelativePackagePath is promoted as '$($ScriptInfo.Status)' but PortabilityReviewStatus is '$($ScriptInfo.PortabilityReviewStatus)'."
    }

    foreach ($metadataField in @('Summary', 'WritesTo')) {
        $metadataValue = [string]$ScriptInfo.$metadataField
        if ([string]::IsNullOrWhiteSpace($metadataValue) -or $metadataValue -match '<[^>]+>') {
            Add-Failure -Message "$RelativePackagePath is promoted as '$($ScriptInfo.Status)' but metadata field '$metadataField' is unfinished."
        }
    }

    if ($Contract -in @('Remediation', 'CustomCompliance')) {
        if ($ScriptInfo.DetectionReviewStatus -ne 'Reviewed') {
            Add-Failure -Message "$RelativePackagePath is promoted as '$($ScriptInfo.Status)' but DetectionReviewStatus is '$($ScriptInfo.DetectionReviewStatus)'."
        }

        if ($ScriptInfo.DetectionEvidenceType -in @('MarkerOnly', 'NeedsReview', 'N/A')) {
            Add-Failure -Message "$RelativePackagePath is promoted as '$($ScriptInfo.Status)' with unsuitable evidence type '$($ScriptInfo.DetectionEvidenceType)'."
        }
    }
}

function Test-CustomComplianceRules {
    param(
        [Parameter(Mandatory = $true)][string]$RulesPath,
        [Parameter(Mandatory = $true)][string]$DiscoverPath,
        [Parameter(Mandatory = $true)][string]$RelativePackagePath,
        [Parameter(Mandatory = $true)][bool]$IsReady
    )

    if (-not (Test-Path -LiteralPath $RulesPath -PathType Leaf)) {
        return
    }

    $rulesFile = Get-Item -LiteralPath $RulesPath
    if ($rulesFile.Length -gt 100KB) {
        Add-Failure -Message "$RelativePackagePath\ComplianceRules.json is larger than the Microsoft 100 KB policy limit."
    }

    try {
        $rulesDocument = Get-Content -LiteralPath $RulesPath -Raw | ConvertFrom-Json
    }
    catch {
        Add-Failure -Message "$RelativePackagePath\ComplianceRules.json could not be parsed: $($_.Exception.Message)"
        return
    }

    if (-not $rulesDocument.PSObject.Properties.Name.Contains('Rules')) {
        Add-Failure -Message "$RelativePackagePath\ComplianceRules.json has no Rules collection."
        return
    }

    $rules = @($rulesDocument.Rules)
    if ($rules.Count -eq 0) {
        $message = "$RelativePackagePath\ComplianceRules.json contains no rules."
        if ($IsReady) { Add-Failure -Message $message } else { Add-Warning -Message $message }
        return
    }

    if ($rules.Count -gt 100) {
        Add-Failure -Message "$RelativePackagePath\ComplianceRules.json contains $($rules.Count) rules; Microsoft allows at most 100."
    }

    $discoverContent = if (Test-Path -LiteralPath $DiscoverPath -PathType Leaf) { Get-Content -LiteralPath $DiscoverPath -Raw } else { '' }

    foreach ($rule in $rules) {
        $propertyNames = @($rule.PSObject.Properties.Name)
        foreach ($requiredProperty in @('SettingName', 'Operator', 'DataType', 'Operand', 'MoreInfoUrl', 'RemediationStrings')) {
            if (-not ($propertyNames -contains $requiredProperty)) {
                Add-Failure -Message "$RelativePackagePath has a Custom Compliance rule missing '$requiredProperty'."
            }
        }

        if ($propertyNames -contains 'Operator' -and $rule.Operator -notin $validComplianceOperators) {
            Add-Failure -Message "$RelativePackagePath rule '$($rule.SettingName)' uses unsupported operator '$($rule.Operator)'."
        }

        if ($propertyNames -contains 'DataType' -and $rule.DataType -notin $validComplianceDataTypes) {
            Add-Failure -Message "$RelativePackagePath rule '$($rule.SettingName)' uses unsupported data type '$($rule.DataType)'."
        }

        if ($propertyNames -contains 'RemediationStrings') {
            $remediationStrings = @($rule.RemediationStrings)
            if ($remediationStrings.Count -eq 0 -or -not (@($remediationStrings.Language) -contains 'en_US')) {
                Add-Failure -Message "$RelativePackagePath rule '$($rule.SettingName)' requires at least one en_US remediation string."
            }
        }

        if ($propertyNames -contains 'SettingName' -and -not [string]::IsNullOrWhiteSpace([string]$rule.SettingName)) {
            $settingPattern = '(?<![A-Za-z0-9_])' + [regex]::Escape([string]$rule.SettingName) + '(?![A-Za-z0-9_])'
            if ($discoverContent -cnotmatch $settingPattern) {
                $message = "$RelativePackagePath rule SettingName '$($rule.SettingName)' is not present with identical case in Discover.ps1."
                if ($IsReady) { Add-Failure -Message $message } else { Add-Warning -Message $message }
            }
        }
    }
}

function Test-ReadOnlyMain {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string]$RelativePackagePath,
        [Parameter(Mandatory = $true)][string]$Role,
        [Parameter(Mandatory = $true)][bool]$IsReady,
        [switch]$RequireJsonOnlyOutput
    )

    if (-not $IsReady -or -not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        return
    }

    $content = Get-Content -LiteralPath $ScriptPath -Raw
    $mainMatch = [regex]::Match($content, '(?ms)^# =========================\r?\n# MAIN\r?\n# =========================\r?\n(?<Body>.*)$')
    if (-not $mainMatch.Success) {
        Add-Failure -Message "$RelativePackagePath has no recognizable MAIN section in $Role for read-only review."
        return
    }

    $mainBody = $mainMatch.Groups['Body'].Value
    $mutationPattern = '(?im)^\s*(Set-(?!StrictMode\b|Variable\b)|Remove-|Clear-|Start-(?!Sleep\b)|Stop-|Restart-|Enable-|Disable-|Install-|Uninstall-|New-(?!Object\b)|Add-(Content\b|LocalGroupMember\b))'
    if ($mainBody -match $mutationPattern) {
        Add-Failure -Message "$RelativePackagePath is promoted but $Role appears to change managed state in MAIN. Detection and discovery must be read-only except for diagnostic logging."
    }

    if ($RequireJsonOnlyOutput) {
        $outputStatements = [regex]::Matches($mainBody, '(?im)^\s*Write-(Output|Host|Information|Warning|Verbose|Debug)\b[^\r\n]*')
        foreach ($outputStatement in $outputStatements) {
            if ($outputStatement.Value -notmatch 'ConvertTo-Json\s+-Compress') {
                Add-Failure -Message "$RelativePackagePath is promoted but Discover.ps1 has non-JSON output in MAIN: '$($outputStatement.Value.Trim())'."
            }
        }
    }
}

foreach ($workload in $workloads) {
    $workloadRoot = Join-Path -Path $RepositoryRoot -ChildPath $workload.Folder
    if (-not (Test-Path -LiteralPath $workloadRoot -PathType Container)) {
        Add-Failure -Message "Missing workload folder '$($workload.Folder)'."
        continue
    }

    foreach ($categoryFolder in @(Get-ChildItem -LiteralPath $workloadRoot -Directory)) {
        foreach ($packageFolder in @(Get-ChildItem -LiteralPath $categoryFolder.FullName -Directory)) {
            $packageCount++
            $relativePackagePath = Get-RelativePath -BasePath $RepositoryRoot -Path $packageFolder.FullName
            $scriptInfoPath = Join-Path -Path $packageFolder.FullName -ChildPath 'ScriptInfo.json'

            if (-not (Test-Path -LiteralPath $scriptInfoPath -PathType Leaf)) {
                Add-Failure -Message "$relativePackagePath is missing ScriptInfo.json."
                continue
            }

            try {
                $scriptInfo = Get-Content -LiteralPath $scriptInfoPath -Raw | ConvertFrom-Json
            }
            catch {
                Add-Failure -Message "$relativePackagePath has invalid ScriptInfo.json: $($_.Exception.Message)"
                continue
            }

            $status = [string]$scriptInfo.Status
            $isReady = $status -in $readyStatuses
            if ($isReady) { $readyCount++ }

            if ($status -notin $validStatuses) {
                Add-Failure -Message "$relativePackagePath has unsupported Status '$status'."
            }

            if ($scriptInfo.Workload -ne $workload.DisplayName) {
                Add-Failure -Message "$relativePackagePath metadata Workload is '$($scriptInfo.Workload)'; expected '$($workload.DisplayName)'."
            }

            if ($scriptInfo.Purpose -ne $categoryFolder.Name) {
                Add-Failure -Message "$relativePackagePath metadata Purpose is '$($scriptInfo.Purpose)'; expected topical category '$($categoryFolder.Name)'."
            }

            Test-UnfinishedLogic -PackagePath $packageFolder.FullName -RelativePackagePath $relativePackagePath -IsReady $isReady
            if ($isReady) {
                Test-ReadyReviewMetadata -ScriptInfo $scriptInfo -RelativePackagePath $relativePackagePath -Contract $workload.Contract
            }

            switch ($workload.Contract) {
                'Remediation' {
                    $detectPath = Join-Path -Path $packageFolder.FullName -ChildPath 'Detect.ps1'
                    $remediatePath = Join-Path -Path $packageFolder.FullName -ChildPath 'Remediate.ps1'
                    [void](Test-RequiredFile -PackagePath $packageFolder.FullName -FileName 'Detect.ps1' -RelativePackagePath $relativePackagePath)
                    [void](Test-RequiredFile -PackagePath $packageFolder.FullName -FileName 'Remediate.ps1' -RelativePackagePath $relativePackagePath)
                    Test-ForbiddenFile -PackagePath $packageFolder.FullName -FileName 'Discover.ps1' -RelativePackagePath $relativePackagePath
                    Test-ForbiddenFile -PackagePath $packageFolder.FullName -FileName 'ComplianceRules.json' -RelativePackagePath $relativePackagePath
                    Test-ExitCodePath -Path $detectPath -RelativePackagePath $relativePackagePath -FileName 'Detect.ps1'
                    Test-ExitCodePath -Path $remediatePath -RelativePackagePath $relativePackagePath -FileName 'Remediate.ps1'
                    Test-ReadOnlyMain -ScriptPath $detectPath -RelativePackagePath $relativePackagePath -Role 'Detect.ps1' -IsReady $isReady

                    if ($scriptInfo.HasRemediation -ne 'Yes') {
                        Add-Failure -Message "$relativePackagePath must set HasRemediation to 'Yes'."
                    }

                    if ($isReady) {
                        $combinedContent = ''
                        if (Test-Path -LiteralPath $detectPath) { $combinedContent += Get-Content -LiteralPath $detectPath -Raw }
                        if (Test-Path -LiteralPath $remediatePath) { $combinedContent += Get-Content -LiteralPath $remediatePath -Raw }
                        if ($combinedContent -match '(?i)\b(Restart-Computer|shutdown\.exe)\b') {
                            Add-Failure -Message "$relativePackagePath contains a reboot command; Microsoft advises against reboot commands in Remediation scripts."
                        }
                    }
                }

                'CustomCompliance' {
                    $discoverPath = Join-Path -Path $packageFolder.FullName -ChildPath 'Discover.ps1'
                    $rulesPath = Join-Path -Path $packageFolder.FullName -ChildPath 'ComplianceRules.json'
                    [void](Test-RequiredFile -PackagePath $packageFolder.FullName -FileName 'Discover.ps1' -RelativePackagePath $relativePackagePath)
                    [void](Test-RequiredFile -PackagePath $packageFolder.FullName -FileName 'ComplianceRules.json' -RelativePackagePath $relativePackagePath)
                    Test-ForbiddenFile -PackagePath $packageFolder.FullName -FileName 'Detect.ps1' -RelativePackagePath $relativePackagePath
                    Test-ForbiddenFile -PackagePath $packageFolder.FullName -FileName 'Remediate.ps1' -RelativePackagePath $relativePackagePath

                    if ($scriptInfo.HasRemediation -ne 'No') {
                        Add-Failure -Message "$relativePackagePath must set HasRemediation to 'No'."
                    }

                    if (Test-Path -LiteralPath $discoverPath -PathType Leaf) {
                        $discoverFile = Get-Item -LiteralPath $discoverPath
                        $discoverContent = Get-Content -LiteralPath $discoverPath -Raw
                        if ($discoverFile.Length -gt 1MB) {
                            Add-Failure -Message "$relativePackagePath\Discover.ps1 is larger than the Microsoft 1 MB script limit."
                        }
                        if ($discoverContent -notmatch 'ConvertTo-Json\s+-Compress') {
                            Add-Failure -Message "$relativePackagePath\Discover.ps1 does not return compressed JSON."
                        }
                    }

                    Test-CustomComplianceRules -RulesPath $rulesPath -DiscoverPath $discoverPath -RelativePackagePath $relativePackagePath -IsReady $isReady
                    Test-ReadOnlyMain -ScriptPath $discoverPath -RelativePackagePath $relativePackagePath -Role 'Discover.ps1' -IsReady $isReady -RequireJsonOnlyOutput
                }

                'Platform' {
                    $powerShellFiles = @(Get-ChildItem -LiteralPath $packageFolder.FullName -Filter '*.ps1' -File)
                    if ($powerShellFiles.Count -ne 1) {
                        Add-Failure -Message "$relativePackagePath must contain exactly one primary .ps1 file; found $($powerShellFiles.Count)."
                    }
                    elseif ($powerShellFiles[0].Length -ge 200KB) {
                        Add-Failure -Message "$relativePackagePath\$($powerShellFiles[0].Name) is not smaller than the Microsoft 200 KB Platform script limit."
                    }

                    foreach ($forbiddenFile in @('Detect.ps1', 'Remediate.ps1', 'Discover.ps1', 'ComplianceRules.json')) {
                        Test-ForbiddenFile -PackagePath $packageFolder.FullName -FileName $forbiddenFile -RelativePackagePath $relativePackagePath
                    }

                    if ($scriptInfo.HasRemediation -ne 'N/A') {
                        Add-Failure -Message "$relativePackagePath must set HasRemediation to 'N/A'."
                    }

                    if ($isReady -and $scriptInfo.DetectionReviewStatus -ne 'NotApplicable') {
                        Add-Failure -Message "$relativePackagePath is a Platform script and must use DetectionReviewStatus 'NotApplicable'."
                    }
                }
            }
        }
    }
}

Write-Output 'Intune workload contract validation summary'
Write-Output "Packages checked: $packageCount"
Write-Output "PilotReady or Validated: $readyCount"
Write-Output "Warnings: $($warnings.Count)"
Write-Output "Failures: $($failures.Count)"

if ($warnings.Count -gt 0 -and $MaximumDetails -gt 0) {
    Write-Output ''
    Write-Output "Warnings (first $([Math]::Min($MaximumDetails, $warnings.Count))):"
    $warnings | Select-Object -First $MaximumDetails | ForEach-Object { Write-Output "WARN: $_" }
}

if ($failures.Count -gt 0) {
    if ($MaximumDetails -gt 0) {
        Write-Output ''
        Write-Output "Failures (first $([Math]::Min($MaximumDetails, $failures.Count))):"
        $failures | Select-Object -First $MaximumDetails | ForEach-Object { Write-Output "FAIL: $_" }
    }

    Write-Output 'Intune workload contract validation failed.'
    exit 1
}

Write-Output 'Intune workload contract validation completed successfully.'
exit 0
