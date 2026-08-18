<#
.SYNOPSIS
    Audits PowerShell scripts for portability and scalability risks.

.DESCRIPTION
    Local maintainer tool for this Intune script library. The script scans
    deployable PowerShell packages and PowerShell templates for patterns that
    can be language-dependent, OS-display-name-dependent, or difficult to
    scale on real endpoints.

    Use -UpdateScriptInfo to stamp package ScriptInfo.json portability
    metadata. Use -UpdateBaseline to refresh the committed finding baseline.
    Use -Check in CI to verify metadata and fail only on new high or medium
    risk findings that are not in the baseline.

.NOTES
    Name:        Test-ScriptPortability.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     Local maintainer
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateSet('All', 'CustomCompliance', 'Remediation', 'Win32', 'Platform', 'Templates')]
    [string]$Scope = 'All',

    [string]$RepositoryRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path,

    [string]$OutputRoot = (Join-Path -Path (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path -ChildPath 'output'),

    [string]$BaselinePath = (Join-Path -Path (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path -ChildPath 'tools\script-portability-baseline.json'),

    [switch]$UpdateScriptInfo,

    [switch]$UpdateBaseline,

    [switch]$Check
)

$ErrorActionPreference = 'Stop'

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

$validRiskAreas = @(
    'Localization',
    'OsVersion',
    'CommandParsing',
    'Scalability',
    'RegistryView',
    'PathAssumption'
)

$jsonReportPath = Join-Path -Path $OutputRoot -ChildPath 'script-portability-results.json'
$csvReportPath = Join-Path -Path $OutputRoot -ChildPath 'script-portability-findings.csv'
$summaryReportPath = Join-Path -Path $OutputRoot -ChildPath 'script-portability-summary.md'

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

function Get-HighestSeverity {
    param(
        [AllowNull()]
        [array]$Severities
    )

    if ($null -eq $Severities -or $Severities.Count -eq 0) {
        return 'None'
    }

    if ($Severities -contains 'High') { return 'High' }
    if ($Severities -contains 'Medium') { return 'Medium' }
    if ($Severities -contains 'Low') { return 'Low' }
    return 'None'
}

function Get-SeverityRank {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('None', 'Low', 'Medium', 'High')]
        [string]$Severity
    )

    switch ($Severity) {
        'High' { return 3 }
        'Medium' { return 2 }
        'Low' { return 1 }
        default { return 0 }
    }
}

function New-FindingId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        $hash = $sha.ComputeHash($bytes)
        return (($hash | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 16)
    }
    finally {
        $sha.Dispose()
    }
}

function Get-CodeLines {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $lines = $Content -split '\r?\n'
    $codeLines = New-Object System.Collections.Generic.List[string]
    $inBlockComment = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        if ($inBlockComment) {
            if ($trimmed -match '#>') {
                $inBlockComment = $false
            }
            continue
        }

        if ($trimmed -match '^<#') {
            if ($trimmed -notmatch '#>') {
                $inBlockComment = $true
            }
            continue
        }

        if ($trimmed -match '^\s*#') {
            continue
        }

        $codeLines.Add($line)
    }

    return $codeLines.ToArray()
}

function Find-FirstCodeLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $lines = $Content -split '\r?\n'
    $inBlockComment = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $trimmed = $line.Trim()

        if ($inBlockComment) {
            if ($trimmed -match '#>') {
                $inBlockComment = $false
            }
            continue
        }

        if ($trimmed -match '^<#') {
            if ($trimmed -notmatch '#>') {
                $inBlockComment = $true
            }
            continue
        }

        if ($trimmed -match '^\s*#') {
            continue
        }

        if ($line -match $Pattern) {
            return [pscustomobject]@{
                Number = $i + 1
                Text = $trimmed
            }
        }
    }

    return $null
}

function Get-ShortText {
    param(
        [AllowNull()]
        [string]$Value,

        [int]$MaximumLength = 160
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $singleLine = $Value.Replace("`r", ' ').Replace("`n", ' ').Trim()
    if ($singleLine.Length -le $MaximumLength) {
        return $singleLine
    }

    return $singleLine.Substring(0, $MaximumLength - 3) + '...'
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
            if ($Scope -eq 'Templates') { continue }
        }

        $purposeFolders = Get-ChildItem -LiteralPath $workloadPath -Directory | Sort-Object -Property Name
        foreach ($purposeFolder in $purposeFolders) {
            $scriptFolders = Get-ChildItem -LiteralPath $purposeFolder.FullName -Directory | Sort-Object -Property Name
            foreach ($scriptFolder in $scriptFolders) {
                [pscustomobject]@{
                    WorkloadFolderName = $workloadFolderName
                    Workload = $workloadDisplayNames[$workloadFolderName]
                    Purpose = $purposeFolder.Name
                    Folder = $scriptFolder
                    PackagePath = Get-RelativePath -BasePath $RepositoryRoot -Path $scriptFolder.FullName
                    ScriptInfoPath = Join-Path -Path $scriptFolder.FullName -ChildPath 'ScriptInfo.json'
                }
            }
        }
    }
}

function Get-ScriptEntries {
    foreach ($scriptFolderInfo in Get-ScriptFolders) {
        $scriptFiles = Get-ChildItem -LiteralPath $scriptFolderInfo.Folder.FullName -Recurse -Filter '*.ps1' -File | Sort-Object -Property FullName

        foreach ($scriptFile in $scriptFiles) {
            [pscustomobject]@{
                Workload = $scriptFolderInfo.Workload
                WorkloadFolderName = $scriptFolderInfo.WorkloadFolderName
                Purpose = $scriptFolderInfo.Purpose
                PackageName = $scriptFolderInfo.Folder.Name
                PackagePath = $scriptFolderInfo.PackagePath
                ScriptInfoPath = $scriptFolderInfo.ScriptInfoPath
                ScriptInfoRelativePath = Get-RelativePath -BasePath $RepositoryRoot -Path $scriptFolderInfo.ScriptInfoPath
                ScriptRole = [System.IO.Path]::GetFileNameWithoutExtension($scriptFile.Name)
                ScriptPath = $scriptFile.FullName
                ScriptRelativePath = Get-RelativePath -BasePath $RepositoryRoot -Path $scriptFile.FullName
                IsPackageScript = $true
            }
        }
    }

    if ($Scope -eq 'All' -or $Scope -eq 'Templates') {
        $templatePath = Join-Path -Path $RepositoryRoot -ChildPath 'templates'
        if (Test-Path -LiteralPath $templatePath -PathType Container) {
            $templateFiles = Get-ChildItem -LiteralPath $templatePath -Filter '*.ps1' -File | Sort-Object -Property FullName
            foreach ($templateFile in $templateFiles) {
                [pscustomobject]@{
                    Workload = 'Repository Template'
                    WorkloadFolderName = 'Templates'
                    Purpose = 'Templates'
                    PackageName = ''
                    PackagePath = ''
                    ScriptInfoPath = ''
                    ScriptInfoRelativePath = ''
                    ScriptRole = [System.IO.Path]::GetFileNameWithoutExtension($templateFile.Name)
                    ScriptPath = $templateFile.FullName
                    ScriptRelativePath = Get-RelativePath -BasePath $RepositoryRoot -Path $templateFile.FullName
                    IsPackageScript = $false
                }
            }
        }
    }
}

function New-PortabilityFinding {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ScriptEntry,

        [Parameter(Mandatory = $true)]
        [string]$RuleId,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Localization', 'OsVersion', 'CommandParsing', 'Scalability', 'RegistryView', 'PathAssumption')]
        [string]$RiskArea,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Low', 'Medium', 'High')]
        [string]$Severity,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [string]$Recommendation,

        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $lineInfo = Find-FirstCodeLine -Content $Content -Pattern $Pattern
    $lineNumber = 0
    $evidence = ''

    if ($null -ne $lineInfo) {
        $lineNumber = $lineInfo.Number
        $evidence = Get-ShortText -Value $lineInfo.Text
    }

    $idSource = "$RuleId|$($ScriptEntry.ScriptRelativePath)|$evidence"

    [pscustomobject]@{
        FindingId = New-FindingId -Value $idSource
        RuleId = $RuleId
        RiskArea = $RiskArea
        Severity = $Severity
        Workload = $ScriptEntry.Workload
        Purpose = $ScriptEntry.Purpose
        PackageName = $ScriptEntry.PackageName
        PackagePath = $ScriptEntry.PackagePath
        ScriptRole = $ScriptEntry.ScriptRole
        ScriptPath = $ScriptEntry.ScriptRelativePath
        Line = $lineNumber
        Evidence = $evidence
        Message = $Message
        Recommendation = $Recommendation
        IsPackageScript = $ScriptEntry.IsPackageScript
    }
}

function Add-PortabilityFinding {
    param(
        [System.Collections.Generic.List[object]]$Findings,

        [Parameter(Mandatory = $true)]
        [object]$ScriptEntry,

        [Parameter(Mandatory = $true)]
        [string]$RuleId,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Localization', 'OsVersion', 'CommandParsing', 'Scalability', 'RegistryView', 'PathAssumption')]
        [string]$RiskArea,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Low', 'Medium', 'High')]
        [string]$Severity,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [string]$Recommendation,

        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $Findings.Add((New-PortabilityFinding `
        -ScriptEntry $ScriptEntry `
        -RuleId $RuleId `
        -RiskArea $RiskArea `
        -Severity $Severity `
        -Message $Message `
        -Recommendation $Recommendation `
        -Content $Content `
        -Pattern $Pattern))
}

function Get-ScriptPortabilityFindings {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ScriptEntry
    )

    $content = Read-TextFile -Path $ScriptEntry.ScriptPath
    $codeLines = Get-CodeLines -Content $content
    $codeText = ($codeLines -join "`n")
    $findings = New-Object System.Collections.Generic.List[object]

    if ([string]::IsNullOrWhiteSpace($codeText)) {
        return @()
    }

    $hasWellKnownSidResolution = ($codeText -match '(?i)(SecurityIdentifier|WellKnownSidType|S-1-5-32-544|S-1-5-32-545|S-1-1-0|S-1-5-18)')
    $localizedBuiltInPrincipalPattern = '(?im)(^\s*\$(?:LocalGroupName|AclIdentity|GroupName)\s*=\s*[''"](?:Administrators|BUILTIN\\Users|Users|Everyone|NT AUTHORITY\\SYSTEM)[''"]|\b(?:Get|Add|Remove)-LocalGroupMember\b[^\r\n]*-Group\s+[''"]Administrators[''"])'

    if ($codeText -match $localizedBuiltInPrincipalPattern -and -not $hasWellKnownSidResolution) {
        Add-PortabilityFinding `
            -Findings $findings `
            -ScriptEntry $ScriptEntry `
            -RuleId 'LOCALIZED_BUILTIN_PRINCIPAL' `
            -RiskArea 'Localization' `
            -Severity 'Medium' `
            -Message 'Script logic uses a localized built-in group or account name.' `
            -Recommendation 'Resolve built-in principals from well-known SIDs, such as S-1-5-32-544 for Administrators or S-1-5-32-545 for Users, before calling local group or ACL APIs.' `
            -Content $content `
            -Pattern $localizedBuiltInPrincipalPattern
    }

    $systemAccountPattern = '(?i)[''"]NT AUTHORITY\\SYSTEM[''"]'
    if ($codeText -match $systemAccountPattern -and -not $hasWellKnownSidResolution) {
        Add-PortabilityFinding `
            -Findings $findings `
            -ScriptEntry $ScriptEntry `
            -RuleId 'LOCALIZED_SYSTEM_ACCOUNT_STRING' `
            -RiskArea 'Localization' `
            -Severity 'Low' `
            -Message 'Script compares the SYSTEM account by localized name.' `
            -Recommendation 'Compare the current identity SID to S-1-5-18 when execution context must be checked.' `
            -Content $content `
            -Pattern $systemAccountPattern
    }

    $hardCodedOsVersionPattern = '(?im)^\s*\$[A-Za-z0-9_]*(?:ProductVersion|ProductName|ProductNamePatterns|WindowsVersion|OSVersion|ExpectedProductVersion)[A-Za-z0-9_]*\s*=\s*.*[''"]Windows\s+(?:10|11|Server)'
    if ($codeText -match $hardCodedOsVersionPattern) {
        $severity = 'Medium'
        if ($ScriptEntry.PackageName -match '(?i)(Feature-Update|Target-Release|Windows-Update-Policy)' -or $ScriptEntry.ScriptRelativePath -match '(?i)Windows-Updates') {
            $severity = 'Low'
        }

        Add-PortabilityFinding `
            -Findings $findings `
            -ScriptEntry $ScriptEntry `
            -RuleId 'HARDCODED_OS_DISPLAY_VERSION' `
            -RiskArea 'OsVersion' `
            -Severity $severity `
            -Message 'Script logic depends on a hardcoded Windows display version string.' `
            -Recommendation 'Use build number, UBR, EditionID, policy registry values, feature detection, or documented target-release policy values instead of localized display names.' `
            -Content $content `
            -Pattern $hardCodedOsVersionPattern
    }

    $osDisplayComparisonPattern = '(?i)\b(ProductName|Caption)\b[^\r\n]*(?:-like|-match|-eq|-ne)'
    if ($codeText -match $osDisplayComparisonPattern) {
        Add-PortabilityFinding `
            -Findings $findings `
            -ScriptEntry $ScriptEntry `
            -RuleId 'OS_DISPLAY_NAME_COMPARISON' `
            -RiskArea 'OsVersion' `
            -Severity 'Medium' `
            -Message 'Script compares OS ProductName or Caption text.' `
            -Recommendation 'Use EditionID, OperatingSystemSKU, build number, UBR, or capability checks for decisions; keep display strings for reporting only.' `
            -Content $content `
            -Pattern $osDisplayComparisonPattern
    }

    $windowsCommandPattern = '(?i)\b(powercfg(?:\.exe)?|dsregcmd|reagentc|slmgr|gpresult|wevtutil|pnputil|netsh)\b'
    $textParsingPattern = '(?i)(Select-String|\s-match\s|\s-like\s|\s-split\s|switch\s+-Regex)'
    if ($codeText -match $windowsCommandPattern -and $codeText -match $textParsingPattern) {
        Add-PortabilityFinding `
            -Findings $findings `
            -ScriptEntry $ScriptEntry `
            -RuleId 'LOCALIZED_COMMAND_OUTPUT_PARSING' `
            -RiskArea 'CommandParsing' `
            -Severity 'Medium' `
            -Message 'Script appears to parse human-readable command output.' `
            -Recommendation 'Prefer CIM/WMI, registry values, event IDs, XML/JSON output, documented APIs, GUIDs, or exit codes instead of localized text.' `
            -Content $content `
            -Pattern $windowsCommandPattern
    }
    elseif ($codeText -match $windowsCommandPattern) {
        Add-PortabilityFinding `
            -Findings $findings `
            -ScriptEntry $ScriptEntry `
            -RuleId 'WINDOWS_COMMAND_REVIEW' `
            -RiskArea 'CommandParsing' `
            -Severity 'Low' `
            -Message 'Script invokes a Windows command whose output can be localized or version-dependent.' `
            -Recommendation 'Verify that the script does not depend on localized command text, or replace command parsing with structured PowerShell, CIM, registry, XML, JSON, GUID, or exit-code evidence.' `
            -Content $content `
            -Pattern $windowsCommandPattern
    }

    $win32ProductPattern = '(?i)\bWin32_Product\b'
    if ($codeText -match $win32ProductPattern) {
        Add-PortabilityFinding `
            -Findings $findings `
            -ScriptEntry $ScriptEntry `
            -RuleId 'WIN32_PRODUCT_USAGE' `
            -RiskArea 'Scalability' `
            -Severity 'High' `
            -Message 'Script queries Win32_Product, which is slow and can trigger installer consistency checks.' `
            -Recommendation 'Read application inventory from registry uninstall keys, package-specific markers, or a trusted inventory source instead.' `
            -Content $content `
            -Pattern $win32ProductPattern
    }

    $recursiveScanPattern = '(?i)\bGet-ChildItem\b[^|\r\n]*-Recurse\b'
    $hasExplicitRecursiveBound = ($codeText -match '(?i)(-Depth\b|\$Max(?:imum)?[A-Za-z0-9_]*(?:Items|Files|Folders|Depth|Count))')
    if ($codeText -match $recursiveScanPattern -and -not $hasExplicitRecursiveBound) {
        Add-PortabilityFinding `
            -Findings $findings `
            -ScriptEntry $ScriptEntry `
            -RuleId 'UNBOUNDED_RECURSIVE_SCAN' `
            -RiskArea 'Scalability' `
            -Severity 'Medium' `
            -Message 'Script performs a recursive filesystem scan without an explicit bound.' `
            -Recommendation 'Add a max depth, max items, max age, explicit root scope, or streaming enumeration with an early stop condition.' `
            -Content $content `
            -Pattern $recursiveScanPattern
    }

    $wholeWinEventPattern = '(?i)\bGet-WinEvent\b(?![^\r\n]*-(MaxEvents|FilterHashtable|FilterXml|ListLog))'
    if ($codeText -match $wholeWinEventPattern) {
        Add-PortabilityFinding `
            -Findings $findings `
            -ScriptEntry $ScriptEntry `
            -RuleId 'UNBOUNDED_WIN_EVENT_QUERY' `
            -RiskArea 'Scalability' `
            -Severity 'Medium' `
            -Message 'Script queries Windows event logs without a bounded filter.' `
            -Recommendation 'Use -MaxEvents, -FilterHashtable, -FilterXml, event IDs, provider names, or time bounds.' `
            -Content $content `
            -Pattern $wholeWinEventPattern
    }

    $wholeEventLogPattern = '(?i)\bGet-EventLog\b(?![^\r\n]*-(Newest|After|Before|InstanceId|Source))'
    if ($codeText -match $wholeEventLogPattern) {
        Add-PortabilityFinding `
            -Findings $findings `
            -ScriptEntry $ScriptEntry `
            -RuleId 'UNBOUNDED_EVENT_LOG_QUERY' `
            -RiskArea 'Scalability' `
            -Severity 'Medium' `
            -Message 'Script queries classic event logs without a bounded filter.' `
            -Recommendation 'Use -Newest, -After, -Before, -InstanceId, -Source, or Get-WinEvent with a FilterHashtable.' `
            -Content $content `
            -Pattern $wholeEventLogPattern
    }

    $uninstallRootPattern = '(?i)HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall'
    if ($codeText -match $uninstallRootPattern -and $codeText -notmatch '(?i)WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall') {
        Add-PortabilityFinding `
            -Findings $findings `
            -ScriptEntry $ScriptEntry `
            -RuleId 'UNINSTALL_REGISTRY_VIEW' `
            -RiskArea 'RegistryView' `
            -Severity 'Medium' `
            -Message 'Script reads the native uninstall registry view without the 32-bit uninstall view.' `
            -Recommendation 'Check both native and WOW6432Node uninstall roots, or use Microsoft.Win32.RegistryView explicitly.' `
            -Content $content `
            -Pattern $uninstallRootPattern
    }

    $ambiguousHklmSoftwarePattern = '(?i)\b(Get|Set|New|Remove)-ItemProperty\b[^\r\n]*HKLM:\\SOFTWARE'
    if ($codeText -match $ambiguousHklmSoftwarePattern -and $codeText -notmatch '(?i)(WOW6432Node|RegistryView|Is64BitProcess|64-bit|Requires64Bit)') {
        Add-PortabilityFinding `
            -Findings $findings `
            -ScriptEntry $ScriptEntry `
            -RuleId 'AMBIGUOUS_HKLM_SOFTWARE_VIEW' `
            -RiskArea 'RegistryView' `
            -Severity 'Low' `
            -Message 'Script accesses HKLM:\SOFTWARE without making registry view expectations explicit.' `
            -Recommendation 'Document the required 64-bit PowerShell context or use Microsoft.Win32.RegistryView when registry redirection can affect results.' `
            -Content $content `
            -Pattern $ambiguousHklmSoftwarePattern
    }

    $hardcodedUsersPathPattern = '(?i)[''"]C:\\Users(?:\\|[''"])'
    if ($codeText -match $hardcodedUsersPathPattern -and $codeText -notmatch '(?i)Win32_UserProfile|ProfileList') {
        Add-PortabilityFinding `
            -Findings $findings `
            -ScriptEntry $ScriptEntry `
            -RuleId 'HARDCODED_USERS_PATH' `
            -RiskArea 'PathAssumption' `
            -Severity 'Medium' `
            -Message 'Script assumes user profiles live under C:\Users.' `
            -Recommendation 'Discover profile locations from Win32_UserProfile, ProfileList, known folders, or environment APIs.' `
            -Content $content `
            -Pattern $hardcodedUsersPathPattern
    }

    $hardcodedProgramFilesPattern = '(?i)[''"]C:\\Program Files(?:\\|[''"])'
    if ($codeText -match $hardcodedProgramFilesPattern -and $codeText -notmatch '(?i)\$env:ProgramFiles|ProgramW6432|ProgramFiles\(x86\)|KnownFolder') {
        Add-PortabilityFinding `
            -Findings $findings `
            -ScriptEntry $ScriptEntry `
            -RuleId 'HARDCODED_PROGRAM_FILES_PATH' `
            -RiskArea 'PathAssumption' `
            -Severity 'Low' `
            -Message 'Script assumes Program Files is on the C: drive.' `
            -Recommendation 'Use $env:ProgramFiles, $env:ProgramW6432, $env:ProgramFiles(x86), or a known-folder API instead of a fixed drive path.' `
            -Content $content `
            -Pattern $hardcodedProgramFilesPattern
    }

    return $findings.ToArray()
}

function Read-ScriptInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-ScriptInfoStringValue {
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

function Get-ScriptInfoArrayValue {
    param(
        [AllowNull()]
        [object]$ScriptInfo,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $ScriptInfo) {
        return @()
    }

    if ($ScriptInfo.PSObject.Properties.Name -contains $Name -and $null -ne $ScriptInfo.$Name) {
        return @($ScriptInfo.$Name | ForEach-Object { [string]$_ })
    }

    return @()
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
            'PortabilityReviewStatus' { $ordered[$propertyName] = $AuditResult.PortabilityReviewStatus }
            'PortabilityRiskLevel' { $ordered[$propertyName] = $AuditResult.PortabilityRiskLevel }
            'PortabilityRiskAreas' { $ordered[$propertyName] = @($AuditResult.PortabilityRiskAreas) }
            'PortabilityNotes' { $ordered[$propertyName] = $AuditResult.PortabilityNotes }
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

function Update-ScriptInfoPortability {
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

function Get-PortabilityNotes {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RiskLevel,

        [array]$RiskAreas,

        [Parameter(Mandatory = $true)]
        [int]$FindingCount
    )

    if ($RiskLevel -eq 'None') {
        return 'No portability risks detected by static audit.'
    }

    $areaText = if ($RiskAreas.Count -gt 0) { ($RiskAreas -join ', ') } else { 'none' }
    return "Static audit found $FindingCount portability finding(s): $areaText."
}

function New-PackageAuditResult {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ScriptFolderInfo,

        [Parameter(Mandatory = $true)]
        [hashtable]$FindingsByPackage
    )

    $packageFindings = @()
    if ($FindingsByPackage.ContainsKey($ScriptFolderInfo.PackagePath)) {
        $packageFindingList = $FindingsByPackage[$ScriptFolderInfo.PackagePath]
        if ($null -ne $packageFindingList -and $packageFindingList.PSObject.Methods.Name -contains 'ToArray') {
            $packageFindings = @($packageFindingList.ToArray())
        }
        else {
            $packageFindings = @($packageFindingList)
        }
    }

    $scriptInfo = Read-ScriptInfo -Path $ScriptFolderInfo.ScriptInfoPath
    $riskAreas = @($packageFindings | Select-Object -ExpandProperty RiskArea -Unique | Sort-Object)
    $riskLevel = Get-HighestSeverity -Severities @($packageFindings | Select-Object -ExpandProperty Severity)
    $reviewStatus = if ($riskLevel -eq 'High' -or $riskLevel -eq 'Medium') { 'NeedsReview' } else { 'Reviewed' }
    $notes = Get-PortabilityNotes -RiskLevel $riskLevel -RiskAreas $riskAreas -FindingCount $packageFindings.Count

    $metadataReviewStatus = Get-ScriptInfoStringValue -ScriptInfo $scriptInfo -Name 'PortabilityReviewStatus'
    $metadataRiskLevel = Get-ScriptInfoStringValue -ScriptInfo $scriptInfo -Name 'PortabilityRiskLevel'
    $metadataRiskAreas = @(Get-ScriptInfoArrayValue -ScriptInfo $scriptInfo -Name 'PortabilityRiskAreas' | Sort-Object)
    $metadataNotes = Get-ScriptInfoStringValue -ScriptInfo $scriptInfo -Name 'PortabilityNotes'

    $metadataAreasText = ($metadataRiskAreas -join '|')
    $expectedAreasText = (@($riskAreas | Sort-Object) -join '|')
    $metadataCurrent = (
        $metadataReviewStatus -eq $reviewStatus -and
        $metadataRiskLevel -eq $riskLevel -and
        $metadataAreasText -eq $expectedAreasText -and
        $metadataNotes -eq $notes
    )

    [pscustomobject]@{
        Workload = $ScriptFolderInfo.Workload
        Purpose = $ScriptFolderInfo.Purpose
        PackageName = $ScriptFolderInfo.Folder.Name
        PackagePath = $ScriptFolderInfo.PackagePath
        ScriptInfoPath = $ScriptFolderInfo.ScriptInfoPath
        ScriptInfoRelativePath = Get-RelativePath -BasePath $RepositoryRoot -Path $ScriptFolderInfo.ScriptInfoPath
        PortabilityReviewStatus = $reviewStatus
        PortabilityRiskLevel = $riskLevel
        PortabilityRiskAreas = @($riskAreas)
        PortabilityNotes = $notes
        FindingCount = $packageFindings.Count
        MetadataReviewStatus = $metadataReviewStatus
        MetadataRiskLevel = $metadataRiskLevel
        MetadataRiskAreas = @($metadataRiskAreas)
        MetadataNotes = $metadataNotes
        MetadataCurrent = $metadataCurrent
    }
}

function Read-Baseline {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{
            SchemaVersion = 1
            RuleVersion = '1.0'
            FindingIds = @()
            Findings = @()
        }
    }

    $baseline = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $ids = @()
    if ($baseline.PSObject.Properties.Name -contains 'FindingIds') {
        $ids = @($baseline.FindingIds | ForEach-Object { [string]$_ })
    }
    elseif ($baseline.PSObject.Properties.Name -contains 'Findings') {
        $ids = @($baseline.Findings | ForEach-Object { [string]$_.FindingId })
    }

    [pscustomobject]@{
        SchemaVersion = if ($baseline.PSObject.Properties.Name -contains 'SchemaVersion') { $baseline.SchemaVersion } else { 1 }
        RuleVersion = if ($baseline.PSObject.Properties.Name -contains 'RuleVersion') { $baseline.RuleVersion } else { '1.0' }
        FindingIds = @($ids)
        Findings = if ($baseline.PSObject.Properties.Name -contains 'Findings') { @($baseline.Findings) } else { @() }
    }
}

function Write-Baseline {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Findings,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $orderedFindings = @($Findings | Sort-Object -Property Severity, RiskArea, RuleId, ScriptPath, Line | ForEach-Object {
        [ordered]@{
            FindingId = $_.FindingId
            Severity = $_.Severity
            RiskArea = $_.RiskArea
            RuleId = $_.RuleId
            ScriptPath = $_.ScriptPath
            Line = $_.Line
            PackagePath = $_.PackagePath
            Message = $_.Message
            Recommendation = $_.Recommendation
        }
    })

    $baseline = [ordered]@{
        SchemaVersion = 1
        RuleVersion = '1.0'
        GeneratedAt = (Get-Date).ToString('o')
        FindingIds = @($orderedFindings | ForEach-Object { $_.FindingId })
        Findings = $orderedFindings
    }

    $baseline | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Test-Baseline {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Findings,

        [Parameter(Mandatory = $true)]
        [object]$Baseline
    )

    $baselineIds = @($Baseline.FindingIds | ForEach-Object { [string]$_ })
    $currentIds = @($Findings | ForEach-Object { [string]$_.FindingId })
    $currentBlockingFindings = @($Findings | Where-Object { $_.Severity -in @('High', 'Medium') })
    $newBlockingFindings = @($currentBlockingFindings | Where-Object { $baselineIds -notcontains $_.FindingId })
    $resolvedFindingIds = @($baselineIds | Where-Object { $currentIds -notcontains $_ })

    [pscustomobject]@{
        BaselineFindingCount = $baselineIds.Count
        CurrentFindingCount = $currentIds.Count
        CurrentBlockingFindingCount = $currentBlockingFindings.Count
        NewBlockingFindings = $newBlockingFindings
        ResolvedFindingIds = $resolvedFindingIds
    }
}

function New-FindingCsvRows {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Findings
    )

    foreach ($finding in $Findings) {
        [pscustomobject]@{
            FindingId = $finding.FindingId
            Severity = $finding.Severity
            RiskArea = $finding.RiskArea
            RuleId = $finding.RuleId
            Workload = $finding.Workload
            Purpose = $finding.Purpose
            PackageName = $finding.PackageName
            ScriptPath = $finding.ScriptPath
            Line = $finding.Line
            Evidence = $finding.Evidence
            Message = $finding.Message
            Recommendation = $finding.Recommendation
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
        [array]$Findings,

        [Parameter(Mandatory = $true)]
        [array]$PackageResults,

        [Parameter(Mandatory = $true)]
        [object]$BaselineResult,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $staleMetadata = @($PackageResults | Where-Object { -not $_.MetadataCurrent })
    $needsReviewPackages = @($PackageResults | Where-Object { $_.PortabilityReviewStatus -eq 'NeedsReview' })

    $lines.Add('# Script Portability Audit Summary')
    $lines.Add('')
    $lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $lines.Add('')
    $lines.Add('## Run Settings')
    $lines.Add('')
    $lines.Add('| Setting | Value |')
    $lines.Add('| --- | --- |')
    $lines.Add("| Scope | $Scope |")
    $lines.Add("| UpdateScriptInfo | $([bool]$UpdateScriptInfo) |")
    $lines.Add("| UpdateBaseline | $([bool]$UpdateBaseline) |")
    $lines.Add("| Check | $([bool]$Check) |")
    $lines.Add("| Baseline | $BaselinePath |")
    $lines.Add('')
    $lines.Add('## Results')
    $lines.Add('')
    $lines.Add('| Metric | Count |')
    $lines.Add('| --- | ---: |')
    $lines.Add("| Packages audited | $($PackageResults.Count) |")
    $lines.Add("| Findings | $($Findings.Count) |")
    $lines.Add("| Packages needing review | $($needsReviewPackages.Count) |")
    $lines.Add("| Metadata not current | $($staleMetadata.Count) |")
    $lines.Add("| Baseline findings | $($BaselineResult.BaselineFindingCount) |")
    $lines.Add("| New blocking findings | $($BaselineResult.NewBlockingFindings.Count) |")
    $lines.Add("| Resolved baseline findings | $($BaselineResult.ResolvedFindingIds.Count) |")
    $lines.Add('')

    if ($Findings.Count -gt 0) {
        $lines.Add('## By Severity')
        $lines.Add('')
        Add-MarkdownCountTable -Lines $lines -Rows @($Findings | Group-Object -Property Severity | Sort-Object Name) -FirstHeader 'Severity'
        $lines.Add('')
        $lines.Add('## By Risk Area')
        $lines.Add('')
        Add-MarkdownCountTable -Lines $lines -Rows @($Findings | Group-Object -Property RiskArea | Sort-Object Name) -FirstHeader 'Risk Area'
        $lines.Add('')
    }

    if ($BaselineResult.NewBlockingFindings.Count -gt 0) {
        $lines.Add('## New Blocking Findings')
        $lines.Add('')
        $lines.Add('| Severity | Risk Area | Script | Rule | Message |')
        $lines.Add('| --- | --- | --- | --- | --- |')

        foreach ($finding in @($BaselineResult.NewBlockingFindings | Select-Object -First 100)) {
            $scriptPath = $finding.ScriptPath -replace '\|', '/'
            $message = $finding.Message -replace '\|', '/'
            $lines.Add("| $($finding.Severity) | $($finding.RiskArea) | ``$scriptPath`` | $($finding.RuleId) | $message |")
        }

        if ($BaselineResult.NewBlockingFindings.Count -gt 100) {
            $lines.Add('')
            $lines.Add("Only the first 100 new blocking findings are shown. See $csvReportPath for the full list.")
        }

        $lines.Add('')
    }

    if ($needsReviewPackages.Count -gt 0) {
        $lines.Add('## Packages Needing Review')
        $lines.Add('')
        $lines.Add('| Risk | Areas | Package | Notes |')
        $lines.Add('| --- | --- | --- | --- |')

        foreach ($package in @($needsReviewPackages | Select-Object -First 100)) {
            $packagePath = $package.PackagePath -replace '\|', '/'
            $areas = (@($package.PortabilityRiskAreas) -join ', ') -replace '\|', '/'
            $notes = $package.PortabilityNotes -replace '\|', '/'
            $lines.Add("| $($package.PortabilityRiskLevel) | $areas | ``$packagePath`` | $notes |")
        }

        if ($needsReviewPackages.Count -gt 100) {
            $lines.Add('')
            $lines.Add("Only the first 100 needs-review packages are shown. See $csvReportPath for the full list.")
        }

        $lines.Add('')
    }

    if ($staleMetadata.Count -gt 0) {
        $lines.Add('## Metadata Not Current')
        $lines.Add('')
        $lines.Add('| ScriptInfo | Expected Review | Current Review | Expected Risk | Current Risk |')
        $lines.Add('| --- | --- | --- | --- | --- |')

        foreach ($package in @($staleMetadata | Select-Object -First 100)) {
            $scriptInfoPath = $package.ScriptInfoRelativePath -replace '\|', '/'
            $lines.Add("| ``$scriptInfoPath`` | $($package.PortabilityReviewStatus) | $($package.MetadataReviewStatus) | $($package.PortabilityRiskLevel) | $($package.MetadataRiskLevel) |")
        }

        if ($staleMetadata.Count -gt 100) {
            $lines.Add('')
            $lines.Add("Only the first 100 stale metadata entries are shown. See $csvReportPath for the full list.")
        }

        $lines.Add('')
    }

    $lines.Add('## Notes')
    $lines.Add('')
    $lines.Add('- `Localization` covers localized built-in account/group names and localized account string comparisons.')
    $lines.Add('- `OsVersion` covers hardcoded Windows display versions or OS display-name comparisons.')
    $lines.Add('- `CommandParsing` covers command output that may be localized or version-dependent.')
    $lines.Add('- `Scalability` covers unbounded filesystem/event scans and Win32_Product usage.')
    $lines.Add('- `RegistryView` covers ambiguous 32-bit/64-bit registry access.')
    $lines.Add('- `PathAssumption` covers fixed profile or Program Files paths.')

    Set-Content -LiteralPath $Path -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
}

if ($Check -and ($UpdateScriptInfo -or $UpdateBaseline)) {
    throw 'Use -Check by itself, or use update switches without -Check.'
}

if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
    New-Item -Path $OutputRoot -ItemType Directory -Force | Out-Null
}

$scriptEntries = @(Get-ScriptEntries)
$findings = New-Object System.Collections.Generic.List[object]

foreach ($scriptEntry in $scriptEntries) {
    foreach ($finding in @(Get-ScriptPortabilityFindings -ScriptEntry $scriptEntry)) {
        $findings.Add($finding)
    }
}

$findingsByPackage = @{}
foreach ($finding in @($findings | Where-Object { -not [string]::IsNullOrWhiteSpace($_.PackagePath) })) {
    if (-not $findingsByPackage.ContainsKey($finding.PackagePath)) {
        $findingsByPackage[$finding.PackagePath] = New-Object System.Collections.Generic.List[object]
    }

    $findingsByPackage[$finding.PackagePath].Add($finding)
}

$packageResults = @(Get-ScriptFolders | ForEach-Object { New-PackageAuditResult -ScriptFolderInfo $_ -FindingsByPackage $findingsByPackage })

if ($UpdateScriptInfo) {
    foreach ($packageResult in $packageResults) {
        Update-ScriptInfoPortability -AuditResult $packageResult
    }

    $packageResults = @(Get-ScriptFolders | ForEach-Object { New-PackageAuditResult -ScriptFolderInfo $_ -FindingsByPackage $findingsByPackage })
}

$findingArray = @($findings.ToArray())

if ($UpdateBaseline) {
    Write-Baseline -Findings $findingArray -Path $BaselinePath
}

$baseline = Read-Baseline -Path $BaselinePath
$baselineResult = Test-Baseline -Findings $findingArray -Baseline $baseline

$report = [ordered]@{
    GeneratedAt = (Get-Date).ToString('o')
    Scope = $Scope
    ScriptCount = $scriptEntries.Count
    PackageCount = $packageResults.Count
    FindingCount = $findingArray.Count
    Baseline = $baselineResult
    Packages = $packageResults
    Findings = @($findingArray | Sort-Object -Property Severity, RiskArea, RuleId, ScriptPath, Line)
}

$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonReportPath -Encoding UTF8

$findingCsvRows = @(New-FindingCsvRows -Findings $findingArray)
if ($findingCsvRows.Count -gt 0) {
    $findingCsvRows | Export-Csv -LiteralPath $csvReportPath -NoTypeInformation -Encoding UTF8
}
else {
    Set-Content -LiteralPath $csvReportPath -Value '' -Encoding UTF8
}

Write-SummaryReport -Findings $findingArray -PackageResults $packageResults -BaselineResult $baselineResult -Path $summaryReportPath

$staleMetadataCount = @($packageResults | Where-Object { -not $_.MetadataCurrent }).Count
$needsReviewCount = @($packageResults | Where-Object { $_.PortabilityReviewStatus -eq 'NeedsReview' }).Count

Write-Output "Script portability audit report written to '$summaryReportPath'."
Write-Output "Scripts: $($scriptEntries.Count); Packages: $($packageResults.Count); Findings: $($findingArray.Count); NeedsReview: $needsReviewCount; MetadataNotCurrent: $staleMetadataCount; NewBlockingFindings: $($baselineResult.NewBlockingFindings.Count)."

if ($Check -and -not (Test-Path -LiteralPath $BaselinePath -PathType Leaf)) {
    Write-Output "Script portability baseline '$BaselinePath' does not exist. Run tools\Test-ScriptPortability.ps1 -UpdateBaseline and commit the result."
    exit 1
}

if ($Check -and $staleMetadataCount -gt 0) {
    Write-Output 'Script portability metadata is not current. Run tools\Test-ScriptPortability.ps1 -UpdateScriptInfo and commit the result.'
    exit 1
}

if ($Check -and $baselineResult.NewBlockingFindings.Count -gt 0) {
    Write-Output 'One or more new high or medium script portability findings are not in the baseline.'
    exit 1
}

exit 0
