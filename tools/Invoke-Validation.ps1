<#
.SYNOPSIS
    Runs fast changed-package or full repository validation.

.DESCRIPTION
    Resolves changed packages from git, escalates global changes to full
    validation, invokes the existing validators in summary mode, optionally
    validates a local tenant profile and safely smoke-tests read-only scripts,
    then writes deterministic JSON, Markdown, and Pester NUnit artifacts.
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateSet('Changed', 'Full')]
    [string]$Scope = 'Changed',

    [string]$BaseRef,

    [string]$HeadRef = 'HEAD',

    [string]$TenantProfilePath,

    [switch]$EnableSmoke,

    [string]$OutputRoot = (Join-Path -Path (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path -ChildPath 'output\validation'),

    [switch]$CI,

    [string]$RepositoryRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path
)

$ErrorActionPreference = 'Stop'
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture
[System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::InvariantCulture
$startedAt = [datetime]::UtcNow
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath 'IntuneLibrary.Validation.psm1'
Import-Module -Name $modulePath -Force

if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) {
    New-Item -Path $OutputRoot -ItemType Directory -Force | Out-Null
}
$OutputRoot = (Resolve-Path -LiteralPath $OutputRoot).Path

$resolution = Resolve-ValidationScope -Scope $Scope -RepositoryRoot $RepositoryRoot -BaseRef $BaseRef -HeadRef $HeadRef
Write-Output "Validation scope: requested=$($resolution.RequestedScope); effective=$($resolution.EffectiveScope); packages=$($resolution.PackageCount)."
if (-not [string]::IsNullOrWhiteSpace([string]$resolution.EscalationReason)) {
    Write-Output "Escalated to full validation: $($resolution.EscalationReason)"
}

$engineCandidates = @(
    (Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'),
    (Join-Path -Path $PSHOME -ChildPath 'powershell.exe'),
    (Join-Path -Path $env:WINDIR -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe')
)
$enginePath = @($engineCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1)
if ($enginePath.Count -eq 0) { throw 'No PowerShell child-process executable was found.' }
$enginePath = $enginePath[0]

$validatorReports = New-Object System.Collections.Generic.List[object]
$orchestratorResults = New-Object System.Collections.Generic.List[object]

function Add-OrchestratorResult {
    param(
        [Parameter(Mandatory = $true)][string]$RuleId,
        [Parameter(Mandatory = $true)][ValidateSet('Pass', 'Warning', 'Failure')][string]$Severity,
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$PackagePath = '',
        [string]$File = ''
    )
    $orchestratorResults.Add((New-ValidationRuleResult -RuleId $RuleId -Severity $Severity -Message $Message -PackagePath $PackagePath -File $File))
}

function Invoke-ValidationChildScript {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ScriptName,
        [string[]]$Arguments = @(),
        [string[]]$SelectedPackages = @()
    )

    $resultPath = Join-Path -Path $OutputRoot -ChildPath ("validator-{0}.json" -f $Name.ToLowerInvariant())
    $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath $ScriptName
    $childArguments = @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath)
    $childArguments += @('-RepositoryRoot', $RepositoryRoot)
    $childArguments += $Arguments
    if ($SelectedPackages.Count -gt 0) {
        $childArguments += '-PackagePath'
        $childArguments += $SelectedPackages
    }
    $childArguments += @('-SummaryOnly', '-ResultPath', $resultPath)

    Write-Output "Running $Name validation..."
    Write-Verbose ("Child command: {0} {1}" -f $enginePath, (($childArguments | ForEach-Object { '"' + $_ + '"' }) -join ' '))
    $childOutput = @(& $enginePath @childArguments 2>&1)
    $exitCode = $LASTEXITCODE
    foreach ($line in $childOutput) { Write-Output ([string]$line) }

    if (Test-Path -LiteralPath $resultPath -PathType Leaf) {
        try {
            $report = [System.IO.File]::ReadAllText($resultPath) | ConvertFrom-Json
            $validatorReports.Add($report)
        }
        catch {
            Add-OrchestratorResult -RuleId "Validator.$Name.ResultJson" -Severity Failure -Message "Validator result JSON could not be parsed: $($_.Exception.Message)" -File $resultPath
        }
    }
    else {
        Add-OrchestratorResult -RuleId "Validator.$Name.ResultMissing" -Severity Failure -Message "Validator '$Name' did not write its structured result." -File $scriptPath
    }

    if ($exitCode -ne 0) {
        Add-OrchestratorResult -RuleId "Validator.$Name.ExitCode" -Severity Failure -Message "Validator '$Name' exited with code $exitCode." -File $scriptPath
    }
}

$runPackageValidators = $resolution.EffectiveScope -eq 'Full' -or $resolution.PackagePaths.Count -gt 0
if ($runPackageValidators) {
    $selected = if ($resolution.EffectiveScope -eq 'Full') { @() } else { @($resolution.PackagePaths) }
    Invoke-ValidationChildScript -Name 'Repository' -ScriptName 'Test-Repository.ps1' -SelectedPackages $selected
    Invoke-ValidationChildScript -Name 'WorkloadContracts' -ScriptName 'Test-IntuneWorkloadContracts.ps1' -SelectedPackages $selected
    Invoke-ValidationChildScript -Name 'RegistryRemediationAudit' -ScriptName 'Test-RegistryRemediationAudit.ps1' -SelectedPackages $selected
    Invoke-ValidationChildScript -Name 'DetectionEvidence' -ScriptName 'Test-DetectionEvidence.ps1' -Arguments @('-Check', '-OutputRoot', (Join-Path $OutputRoot 'detection-evidence')) -SelectedPackages $selected
    Invoke-ValidationChildScript -Name 'ScriptPortability' -ScriptName 'Test-ScriptPortability.ps1' -Arguments @('-Check', '-OutputRoot', (Join-Path $OutputRoot 'script-portability')) -SelectedPackages $selected
}
else {
    Add-OrchestratorResult -RuleId 'Scope.NoPackages' -Severity Pass -Message 'No current packages were affected; package validators were skipped.'
}

# Catalog validation is intentionally global for every scope, including deletions.
Invoke-ValidationChildScript -Name 'ScriptCatalog' -ScriptName 'Update-ScriptCatalog.ps1' -Arguments @('-Check')

if (-not [string]::IsNullOrWhiteSpace($TenantProfilePath)) {
    $resolvedProfilePath = if ([System.IO.Path]::IsPathRooted($TenantProfilePath)) { $TenantProfilePath } else { Join-Path -Path $RepositoryRoot -ChildPath $TenantProfilePath }
    if (-not (Test-Path -LiteralPath $resolvedProfilePath -PathType Leaf)) {
        Add-OrchestratorResult -RuleId 'TenantProfile.Exists' -Severity Failure -Message "Tenant profile '$resolvedProfilePath' does not exist." -File $resolvedProfilePath
    }
    else {
        foreach ($tenantResult in @(Test-TenantValidationProfile -ProfilePath $resolvedProfilePath -RepositoryRoot $RepositoryRoot)) {
            $orchestratorResults.Add($tenantResult)
        }
    }
}

if ($EnableSmoke) {
    $smokePackages = @()
    $smokeScripts = @()
    if (-not [string]::IsNullOrWhiteSpace($BaseRef)) {
        $smokeResolution = Resolve-ValidationScope -Scope Changed -RepositoryRoot $RepositoryRoot -BaseRef $BaseRef -HeadRef $HeadRef
        $smokeScripts = @($smokeResolution.ChangedPaths | Where-Object {
                $_ -match '^(Detection-Remediation|Win32-Packaged-Scripts)/[^/]+/[^/]+/Detect\.ps1$' -or
                $_ -match '^Custom-Compliance/[^/]+/[^/]+/Discover\.ps1$'
            } | Sort-Object -Unique)
        $smokePackages = @($smokeScripts | ForEach-Object { Get-ValidationPackagePath -RepositoryPath $_ } | Where-Object { $_ } | Sort-Object -Unique)
    }
    elseif ($resolution.EffectiveScope -eq 'Full') {
        $smokePackages = @()
    }

    if (-not [string]::IsNullOrWhiteSpace($BaseRef) -and $smokeScripts.Count -eq 0) {
        Add-OrchestratorResult -RuleId 'Smoke.NoEligibleChanges' -Severity Pass -Message 'No changed Detect.ps1 or Discover.ps1 files were eligible for smoke execution.'
    }
    else {
        $smokeArguments = @('-Scope', 'AllReadOnly', '-TimeoutSeconds', '60', '-OutputRoot', (Join-Path $OutputRoot 'safe-smoke'))
        if ($smokeScripts.Count -gt 0) {
            $smokeArguments += '-ScriptPath'
            $smokeArguments += $smokeScripts
        }
        Invoke-ValidationChildScript -Name 'SafeSmoke' -ScriptName 'Test-DetectionSmoke.ps1' -Arguments $smokeArguments -SelectedPackages $smokePackages
    }
}

$nunitPath = Join-Path -Path $OutputRoot -ChildPath 'pester-results.xml'
$pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object Version -eq ([version]'5.9.0') | Select-Object -First 1
$pesterImportPath = if ($null -ne $pesterModule) { $pesterModule.Path } else { '' }
if ($null -eq $pesterModule -and $null -ne (Get-Command Get-InstalledModule -ErrorAction SilentlyContinue)) {
    $installedPester = Get-InstalledModule -Name Pester -AllVersions -ErrorAction SilentlyContinue | Where-Object Version -eq ([version]'5.9.0') | Select-Object -First 1
    if ($null -ne $installedPester) {
        $candidateManifest = Join-Path -Path $installedPester.InstalledLocation -ChildPath 'Pester.psd1'
        if (Test-Path -LiteralPath $candidateManifest -PathType Leaf) {
            $pesterModule = $installedPester
            $pesterImportPath = $candidateManifest
        }
    }
}
if ($null -eq $pesterModule) {
    $severity = if ($CI) { 'Failure' } else { 'Warning' }
    Add-OrchestratorResult -RuleId 'Pester.Version' -Severity $severity -Message 'Pester 5.9.0 is not installed; unit tests were not run.'
}
else {
    try {
        Import-Module $pesterImportPath -Force
        $configuration = New-PesterConfiguration
        $configuration.Run.Path = Join-Path -Path $RepositoryRoot -ChildPath 'tests'
        $configuration.Run.PassThru = $true
        $configuration.Output.Verbosity = 'Minimal'
        $configuration.TestResult.Enabled = $true
        $configuration.TestResult.OutputPath = $nunitPath
        $configuration.TestResult.OutputFormat = 'NUnitXml'
        $pesterResult = Invoke-Pester -Configuration $configuration
        $pesterSeverity = if ($pesterResult.FailedCount -gt 0) { 'Failure' } else { 'Pass' }
        Add-OrchestratorResult -RuleId 'Pester.Tests' -Severity $pesterSeverity -Message "Pester: Passed=$($pesterResult.PassedCount); Failed=$($pesterResult.FailedCount); Skipped=$($pesterResult.SkippedCount)." -File 'tests'
    }
    catch {
        Add-OrchestratorResult -RuleId 'Pester.Execution' -Severity Failure -Message "Pester could not run: $($_.Exception.Message)" -File 'tests'
    }
}

$allResults = New-Object System.Collections.Generic.List[object]
foreach ($validator in $validatorReports) {
    foreach ($result in @($validator.Results)) { $allResults.Add($result) }
}
foreach ($result in $orchestratorResults) { $allResults.Add($result) }
$orderedResults = @($allResults.ToArray() | Sort-Object @{ Expression = { switch ($_.Severity) { 'Failure' { 0 } 'Warning' { 1 } default { 2 } } } }, RuleId, PackagePath, File, Message)

$passCount = @($orchestratorResults | Where-Object Severity -eq 'Pass').Count
$warningCount = @($orchestratorResults | Where-Object Severity -eq 'Warning').Count
$failureCount = @($orchestratorResults | Where-Object Severity -eq 'Failure').Count
foreach ($validator in $validatorReports) {
    $passCount += [int]$validator.Counts.Pass
    $warningCount += [int]$validator.Counts.Warning
    $failureCount += [int]$validator.Counts.Failure
}
$stopwatch.Stop()
$completedAt = [datetime]::UtcNow

$report = [ordered]@{
    SchemaVersion = '1.0'
    Scope = [ordered]@{
        Requested = $resolution.RequestedScope
        Effective = $resolution.EffectiveScope
        BaseRef = $BaseRef
        HeadRef = $HeadRef
        EscalationReason = $resolution.EscalationReason
        ChangedPaths = @($resolution.ChangedPaths)
        ChangedPackagePaths = @($resolution.ChangedPackagePaths)
        PackagePaths = @($resolution.PackagePaths)
        DeletedOrMissingPackagePaths = @($resolution.DeletedOrMissingPackagePaths)
    }
    Timing = [ordered]@{
        StartedAtUtc = $startedAt.ToString('o')
        CompletedAtUtc = $completedAt.ToString('o')
        DurationMilliseconds = [math]::Round($stopwatch.Elapsed.TotalMilliseconds)
    }
    Counts = [ordered]@{
        Packages = $resolution.PackageCount
        Validators = $validatorReports.Count
        Pass = $passCount
        Warning = $warningCount
        Failure = $failureCount
    }
    Validators = @($validatorReports | Sort-Object Validator)
    Results = $orderedResults
}

$jsonPath = Join-Path -Path $OutputRoot -ChildPath 'validation-results.json'
$summaryPath = Join-Path -Path $OutputRoot -ChildPath 'validation-summary.md'
Write-ValidationResultFile -Path $jsonPath -InputObject $report
Write-ValidationSummary -Report $report -Path $summaryPath

if ($CI -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_STEP_SUMMARY)) {
    Get-Content -LiteralPath $summaryPath -Raw | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Encoding UTF8
}

Write-Output "Validation totals: Pass=$passCount; Warnings=$warningCount; Failures=$failureCount; DurationMs=$($report.Timing.DurationMilliseconds)."
Write-Output "Reports: $jsonPath; $summaryPath"
if ($failureCount -gt 0) { exit 1 }
exit 0
