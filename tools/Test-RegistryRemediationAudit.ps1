<#
.SYNOPSIS
    Validates coverage and promotion gates for registry-based Remediation packages.

.DESCRIPTION
    Discovers Detection-Remediation packages whose detection scripts read the
    Windows registry, verifies that every candidate has one master-audit entry,
    and applies stricter source, configuration, and registry-type gates to
    packages marked PilotReady or Validated.
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path,

    [string]$AuditPath,

    [string[]]$PackagePath,

    [switch]$SummaryOnly,

    [string]$ResultPath
)

$ErrorActionPreference = 'Stop'
$validationModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'IntuneLibrary.Validation.psm1'
Import-Module -Name $validationModulePath -Force

if ([string]::IsNullOrWhiteSpace($AuditPath)) {
    $AuditPath = Join-Path -Path $RepositoryRoot -ChildPath 'validation\registry-remediation-audit.json'
}

$selectedPackagePaths = @($PackagePath | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { ConvertTo-ValidationPath -Path $_ } | Sort-Object -Unique)
$results = New-Object System.Collections.Generic.List[object]
$validRootProperties = @('$schema', 'SchemaVersion', 'ReviewedOn', 'CandidateDefinition', 'Packages')
$validPackageProperties = @('Path', 'Disposition', 'Batch', 'Reason', 'MicrosoftReferences')
$validDispositions = @('PilotReady', 'NeedsSourceVerification', 'NeedsRedesign', 'NeedsCustomization', 'InvalidPlaceholder', 'MarkerOnly', 'Duplicate', 'PreferNativeManagement', 'OutOfScope')
$heldDispositions = @('NeedsSourceVerification', 'NeedsRedesign', 'NeedsCustomization', 'InvalidPlaceholder', 'MarkerOnly', 'Duplicate', 'PreferNativeManagement')
$candidatePattern = '(?i)Registry::|HKLM:|HKCU:|HKEY_LOCAL_MACHINE|HKEY_CURRENT_USER|Get-ItemProperty|Get-ItemPropertyValue|Test-Path.+Registry'

function Add-AuditResult {
    param(
        [Parameter(Mandatory = $true)][string]$RuleId,
        [Parameter(Mandatory = $true)][ValidateSet('Pass', 'Warning', 'Failure')][string]$Severity,
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$Package = '',
        [string]$File = ''
    )

    $results.Add((New-ValidationRuleResult -RuleId $RuleId -Severity $Severity -Message $Message -PackagePath $Package -File $File))
}

function Get-RegistryCandidatePaths {
    $root = Join-Path -Path $RepositoryRoot -ChildPath 'Detection-Remediation'
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $root -Filter 'Detect.ps1' -File -Recurse | ForEach-Object {
        $content = [System.IO.File]::ReadAllText($_.FullName)
        if ($content -match $candidatePattern) {
            ConvertTo-ValidationPath -Path (Get-ValidationRelativePath -BasePath $RepositoryRoot -Path $_.Directory.FullName)
        }
    } | Sort-Object -Unique)
}

function Get-ConfigurationExpression {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string]$VariableName
    )

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        return $null
    }

    $assignment = @($ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $node.Left.VariablePath.UserPath -eq $VariableName
    }, $true) | Select-Object -First 1)

    if ($assignment.Count -eq 0) {
        return $null
    }

    return ([regex]::Replace($assignment[0].Right.Extent.Text, '\s+', ''))
}

if (-not (Test-Path -LiteralPath $AuditPath -PathType Leaf)) {
    Add-AuditResult -RuleId 'RegistryAudit.File' -Severity Failure -Message "Registry audit file is missing: $AuditPath" -File $AuditPath
    $audit = $null
}
else {
    try {
        $audit = [System.IO.File]::ReadAllText($AuditPath) | ConvertFrom-Json
    }
    catch {
        Add-AuditResult -RuleId 'RegistryAudit.Json' -Severity Failure -Message "Registry audit JSON is invalid: $($_.Exception.Message)" -File $AuditPath
        $audit = $null
    }
}

$candidatePaths = @(Get-RegistryCandidatePaths)
$entries = @()

if ($null -ne $audit) {
    foreach ($property in $audit.PSObject.Properties.Name) {
        if ($property -notin $validRootProperties) {
            Add-AuditResult -RuleId 'RegistryAudit.RootProperty' -Severity Failure -Message "Registry audit contains unknown root property '$property'." -File $AuditPath
        }
    }

    if ([string]$audit.SchemaVersion -ne '1.0') {
        Add-AuditResult -RuleId 'RegistryAudit.SchemaVersion' -Severity Failure -Message "Registry audit SchemaVersion must be '1.0'." -File $AuditPath
    }

    $entries = @($audit.Packages)
    $duplicatePaths = @($entries | Group-Object Path | Where-Object Count -gt 1)
    foreach ($duplicate in $duplicatePaths) {
        Add-AuditResult -RuleId 'RegistryAudit.DuplicatePath' -Severity Failure -Message "Registry audit contains duplicate package path '$($duplicate.Name)'." -Package $duplicate.Name -File $AuditPath
    }

    $auditPaths = @($entries | ForEach-Object { ConvertTo-ValidationPath -Path ([string]$_.Path) } | Sort-Object -Unique)
    foreach ($missing in @($candidatePaths | Where-Object { $_ -notin $auditPaths })) {
        Add-AuditResult -RuleId 'RegistryAudit.Coverage' -Severity Failure -Message "Registry candidate '$missing' has no audit entry." -Package $missing -File $AuditPath
    }
    foreach ($extra in @($auditPaths | Where-Object { $_ -notin $candidatePaths })) {
        Add-AuditResult -RuleId 'RegistryAudit.Coverage' -Severity Failure -Message "Audit entry '$extra' is not a current registry candidate." -Package $extra -File $AuditPath
    }

    foreach ($entry in $entries) {
        $path = ConvertTo-ValidationPath -Path ([string]$entry.Path)
        if ($selectedPackagePaths.Count -gt 0 -and -not (Test-ValidationPackageSelected -CandidatePath $path -PackagePath $selectedPackagePaths)) {
            continue
        }

        foreach ($property in $entry.PSObject.Properties.Name) {
            if ($property -notin $validPackageProperties) {
                Add-AuditResult -RuleId 'RegistryAudit.PackageProperty' -Severity Failure -Message "$path contains unknown audit property '$property'." -Package $path -File $AuditPath
            }
        }

        $disposition = [string]$entry.Disposition
        if ($disposition -notin $validDispositions) {
            Add-AuditResult -RuleId 'RegistryAudit.Disposition' -Severity Failure -Message "$path has unsupported disposition '$disposition'." -Package $path -File $AuditPath
            continue
        }

        if ([string]::IsNullOrWhiteSpace([string]$entry.Reason)) {
            Add-AuditResult -RuleId 'RegistryAudit.Reason' -Severity Failure -Message "$path has no audit reason." -Package $path -File $AuditPath
        }

        $references = @($entry.MicrosoftReferences)
        foreach ($reference in $references) {
            if ([string]$reference -notmatch '^https://learn\.microsoft\.com/') {
                Add-AuditResult -RuleId 'RegistryAudit.Reference' -Severity Failure -Message "$path has a non-Microsoft-Learn reference '$reference'." -Package $path -File $AuditPath
            }
        }

        $packageFolder = Join-Path -Path $RepositoryRoot -ChildPath ($path.Replace('/', '\'))
        $scriptInfoPath = Join-Path -Path $packageFolder -ChildPath 'ScriptInfo.json'
        if (-not (Test-Path -LiteralPath $scriptInfoPath -PathType Leaf)) {
            Add-AuditResult -RuleId 'RegistryAudit.PackageExists' -Severity Failure -Message "$path is missing ScriptInfo.json." -Package $path -File $scriptInfoPath
            continue
        }

        $scriptInfo = [System.IO.File]::ReadAllText($scriptInfoPath) | ConvertFrom-Json
        $isPromoted = [string]$scriptInfo.Status -in @('PilotReady', 'Validated')
        if ($isPromoted -and $disposition -ne 'PilotReady') {
            Add-AuditResult -RuleId 'RegistryAudit.Promotion' -Severity Failure -Message "$path is promoted as '$($scriptInfo.Status)' but audit disposition is '$disposition'." -Package $path -File $scriptInfoPath
        }
        if ($disposition -eq 'PilotReady' -and -not $isPromoted) {
            Add-AuditResult -RuleId 'RegistryAudit.Promotion' -Severity Failure -Message "$path has PilotReady audit disposition but ScriptInfo status is '$($scriptInfo.Status)'." -Package $path -File $scriptInfoPath
        }

        if ($disposition -eq 'PilotReady') {
            if ($references.Count -eq 0) {
                Add-AuditResult -RuleId 'RegistryAudit.Reference' -Severity Failure -Message "$path is PilotReady but has no Microsoft Learn reference." -Package $path -File $AuditPath
            }

            $detectPath = Join-Path -Path $packageFolder -ChildPath 'Detect.ps1'
            $remediatePath = Join-Path -Path $packageFolder -ChildPath 'Remediate.ps1'
            $detectConfig = Get-ConfigurationExpression -ScriptPath $detectPath -VariableName 'RegistryValues'
            $remediateConfig = Get-ConfigurationExpression -ScriptPath $remediatePath -VariableName 'RegistryValues'
            if ([string]::IsNullOrWhiteSpace($detectConfig) -or [string]::IsNullOrWhiteSpace($remediateConfig)) {
                Add-AuditResult -RuleId 'RegistryAudit.Configuration' -Severity Failure -Message "$path must define literal RegistryValues in both scripts." -Package $path
            }
            elseif ($detectConfig -cne $remediateConfig) {
                Add-AuditResult -RuleId 'RegistryAudit.Configuration' -Severity Failure -Message "$path detection and remediation RegistryValues configurations do not match." -Package $path
            }

            foreach ($scriptPath in @($detectPath, $remediatePath)) {
                $content = [System.IO.File]::ReadAllText($scriptPath)
                if ($content -notmatch '\.GetValueKind\(') {
                    Add-AuditResult -RuleId 'RegistryAudit.ValueType' -Severity Failure -Message "$path\$([System.IO.Path]::GetFileName($scriptPath)) does not validate the registry value type with GetValueKind()." -Package $path -File $scriptPath
                }
            }

            Add-AuditResult -RuleId 'RegistryAudit.Package' -Severity Pass -Message "$path is source-backed and satisfies registry promotion gates." -Package $path
        }
        elseif ($disposition -in $heldDispositions) {
            Add-AuditResult -RuleId 'RegistryAudit.Held' -Severity Warning -Message "$path is held as '$disposition': $($entry.Reason)" -Package $path
        }
        else {
            Add-AuditResult -RuleId 'RegistryAudit.OutOfScope' -Severity Pass -Message "$path is documented as outside direct registry-policy promotion scope." -Package $path
        }
    }
}

$orderedResults = @($results | Sort-Object Severity, PackagePath, RuleId, Message)
$failures = @($orderedResults | Where-Object Severity -eq 'Failure')
$warnings = @($orderedResults | Where-Object Severity -eq 'Warning')
$passes = @($orderedResults | Where-Object Severity -eq 'Pass')
$structured = [ordered]@{
    Validator = 'RegistryRemediationAudit'
    AuditPath = $AuditPath
    CandidateCount = $candidatePaths.Count
    EntryCount = $entries.Count
    Counts = [ordered]@{ Pass = $passes.Count; Warning = $warnings.Count; Failure = $failures.Count }
    Results = $orderedResults
}

if (-not [string]::IsNullOrWhiteSpace($ResultPath)) {
    Write-ValidationResultFile -Path $ResultPath -InputObject $structured
}

Write-Output "Registry audit: Candidates=$($candidatePaths.Count); Entries=$($entries.Count); Pass=$($passes.Count); Warnings=$($warnings.Count); Failures=$($failures.Count)."
if (-not $SummaryOnly) {
    foreach ($item in @($failures + $warnings | Select-Object -First 30)) {
        Write-Output "[$($item.Severity)] $($item.Message)"
    }
}

if ($failures.Count -gt 0) { exit 1 }
exit 0
