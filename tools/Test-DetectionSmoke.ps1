<#
.SYNOPSIS
    Safely smoke-tests read-only Intune detection and discovery scripts.

.DESCRIPTION
    Executes only Remediation/Win32 Detect.ps1 and Custom Compliance
    Discover.ps1 in isolated Windows PowerShell 5.1 child processes. Each
    process receives temporary ProgramData, LOCALAPPDATA, and APPDATA paths.
    Remediation, install, uninstall, and Platform scripts are never discovered.
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateSet('AllReadOnly', 'AllDetect', 'Remediation', 'Win32', 'CustomCompliance')]
    [string]$Scope = 'AllDetect',

    [ValidateRange(5, 3600)]
    [int]$TimeoutSeconds = 60,

    [ValidateRange(1, 10000)]
    [int]$MaxScripts,

    [switch]$ListOnly,

    [string]$OutputRoot = (Join-Path -Path (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path -ChildPath 'output'),

    [string]$RepositoryRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path,

    [string[]]$PackagePath,

    [string[]]$ScriptPath,

    [switch]$SummaryOnly,

    [string]$ResultPath
)

$ErrorActionPreference = 'Stop'
$validationModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'IntuneLibrary.Validation.psm1'
Import-Module -Name $validationModulePath -Force

$maxScriptsSpecified = $PSBoundParameters.ContainsKey('MaxScripts')
$selectedPackages = @($PackagePath | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { ConvertTo-ValidationPath -Path $_ } | Sort-Object -Unique)
$selectedScripts = @($ScriptPath | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { ConvertTo-ValidationPath -Path $_ } | Sort-Object -Unique)
Write-Verbose "Smoke selection: packages=$($selectedPackages.Count) scripts=$($selectedScripts.Count)"
$powershellPath = Join-Path -Path $env:WINDIR -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
$jsonReportPath = Join-Path -Path $OutputRoot -ChildPath 'detection-smoke-results.json'
$csvReportPath = Join-Path -Path $OutputRoot -ChildPath 'detection-smoke-results.csv'
$summaryReportPath = Join-Path -Path $OutputRoot -ChildPath 'detection-smoke-summary.md'
$warningPattern = '(?i)\b(failed|exception|access denied|could not be validated)\b'

function Get-SafeSmokeScripts {
    $definitions = @(
        [pscustomobject]@{ Scope = 'Remediation'; Workload = 'Detection-Remediation'; FileName = 'Detect.ps1'; Role = 'RemediationDetection' },
        [pscustomobject]@{ Scope = 'Win32'; Workload = 'Win32-Packaged-Scripts'; FileName = 'Detect.ps1'; Role = 'Win32Detection' },
        [pscustomobject]@{ Scope = 'CustomCompliance'; Workload = 'Custom-Compliance'; FileName = 'Discover.ps1'; Role = 'CustomComplianceDiscovery' }
    )

    $items = New-Object System.Collections.Generic.List[object]
    foreach ($definition in $definitions) {
        $include = switch ($Scope) {
            'AllReadOnly' { $true }
            'AllDetect' { $definition.Scope -in @('Remediation', 'Win32') }
            default { $Scope -eq $definition.Scope }
        }
        Write-Verbose "Smoke discovery: scope=$Scope definition=$($definition.Scope) include=$include"
        if (-not $include) { continue }

        $workloadRoot = Join-Path -Path $RepositoryRoot -ChildPath $definition.Workload
        if (-not (Test-Path -LiteralPath $workloadRoot -PathType Container)) { continue }
        $eligibleFiles = @(Get-ChildItem -Path (Join-Path -Path $workloadRoot -ChildPath "*\*\$($definition.FileName)") -File -ErrorAction SilentlyContinue | Sort-Object FullName)
        Write-Verbose "Smoke discovery: workload=$($definition.Workload) files=$($eligibleFiles.Count)"
        foreach ($file in $eligibleFiles) {
            $packageFolder = $file.Directory
            $packageRelative = Get-ValidationRelativePath -BasePath $RepositoryRoot -Path $packageFolder.FullName
            $scriptRelative = Get-ValidationRelativePath -BasePath $RepositoryRoot -Path $file.FullName
            $packageSelected = Test-ValidationPackageSelected -CandidatePath $packageRelative -PackagePath $selectedPackages
            $scriptSelected = $selectedScripts.Count -eq 0 -or $scriptRelative -in $selectedScripts
            if (-not $packageSelected) { continue }
            if (-not $scriptSelected) { continue }

            $items.Add([pscustomobject]@{
                    Workload = $definition.Workload
                    Purpose = $packageFolder.Parent.Name
                    PackageName = $packageFolder.Name
                    PackagePath = $packageRelative
                    Role = $definition.Role
                    ScriptPath = $file.FullName
                    RelativePath = $scriptRelative
                    WorkingDirectory = $packageFolder.FullName
                    RulesPath = if ($definition.Role -eq 'CustomComplianceDiscovery') { Join-Path -Path $packageFolder.FullName -ChildPath 'ComplianceRules.json' } else { '' }
                })
        }
    }

    $ordered = @($items.ToArray() | Sort-Object Workload, Purpose, PackageName)
    if ($maxScriptsSpecified) { return @($ordered | Select-Object -First $MaxScripts) }
    return $ordered
}

function New-SmokeResult {
    param(
        [Parameter(Mandatory = $true)][object]$Script,
        [Parameter(Mandatory = $true)][string]$Status,
        [AllowNull()][object]$ExitCode,
        [int]$DurationMs = 0,
        [bool]$TimedOut = $false,
        [string[]]$FailureReasons = @(),
        [string[]]$WarningReasons = @(),
        [string]$StdOut = '',
        [string]$StdErr = ''
    )

    [pscustomobject][ordered]@{
        Workload = $Script.Workload
        Purpose = $Script.Purpose
        PackageName = $Script.PackageName
        PackagePath = $Script.PackagePath
        Role = $Script.Role
        RelativePath = $Script.RelativePath
        Status = $Status
        Passed = $Status -in @('Passed', 'Listed')
        Warning = $Status -eq 'Warning'
        TimedOut = $TimedOut
        ExitCode = $ExitCode
        DurationMs = $DurationMs
        FailureReasons = @($FailureReasons)
        WarningReasons = @($WarningReasons)
        StdOut = $StdOut.Trim()
        StdErr = $StdErr.Trim()
    }
}

function Invoke-SafeSmokeScript {
    param([Parameter(Mandatory = $true)][object]$Script)

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $failureReasons = New-Object System.Collections.Generic.List[string]
    $warningReasons = New-Object System.Collections.Generic.List[string]
    $stdout = ''
    $stderr = ''
    $exitCode = $null
    $timedOut = $false
    $process = $null
    $isolationRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("intune-validation-" + [guid]::NewGuid().ToString('N'))
    $isolatedProgramData = Join-Path -Path $isolationRoot -ChildPath 'ProgramData'
    $isolatedLocalAppData = Join-Path -Path $isolationRoot -ChildPath 'LocalAppData'
    $isolatedAppData = Join-Path -Path $isolationRoot -ChildPath 'AppData'

    $scriptContent = [System.IO.File]::ReadAllText($Script.ScriptPath)
    $mainMatch = [regex]::Match($scriptContent, '(?ms)^# =========================\r?\n# MAIN\r?\n# =========================\r?\n(?<Body>.*)$')
    if (-not $mainMatch.Success) {
        $failureReasons.Add('The script has no recognizable MAIN section and was not executed.')
    }
    else {
        $mutationPattern = '(?im)^\s*(Set-(?!StrictMode\b|Variable\b)|Remove-|Clear-|Start-(?!Sleep\b)|Stop-|Restart-|Enable-|Disable-|Install-|Uninstall-|New-(?!Object\b)|Add-(Content\b|LocalGroupMember\b))'
        if ($mainMatch.Groups['Body'].Value -match $mutationPattern) {
            $failureReasons.Add("The read-only role appears to change managed state in MAIN ('$($matches[0].Trim())') and was not executed.")
        }
    }

    if ($failureReasons.Count -gt 0) {
        $stopwatch.Stop()
        return New-SmokeResult -Script $Script -Status Failed -ExitCode $null -DurationMs ([math]::Round($stopwatch.Elapsed.TotalMilliseconds)) -FailureReasons @($failureReasons.ToArray())
    }

    try {
        foreach ($directory in @($isolatedProgramData, $isolatedLocalAppData, $isolatedAppData)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }

        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $powershellPath
        $startInfo.Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$($Script.ScriptPath)`""
        $startInfo.WorkingDirectory = $Script.WorkingDirectory
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.CreateNoWindow = $true
        $startInfo.EnvironmentVariables['ProgramData'] = $isolatedProgramData
        $startInfo.EnvironmentVariables['LOCALAPPDATA'] = $isolatedLocalAppData
        $startInfo.EnvironmentVariables['APPDATA'] = $isolatedAppData

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        if (-not $process.Start()) {
            $failureReasons.Add('Windows PowerShell 5.1 process failed to start.')
        }
        else {
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
                $timedOut = $true
                $failureReasons.Add("Timed out after $TimeoutSeconds second(s).")
                try { $process.Kill() } catch { $failureReasons.Add("Timed-out process could not be killed: $($_.Exception.Message)") }
                [void]$process.WaitForExit(5000)
            }
            else {
                $process.WaitForExit()
                $exitCode = $process.ExitCode
            }
            if ($stdoutTask.Wait(5000)) { $stdout = $stdoutTask.Result } else { $failureReasons.Add('STDOUT capture did not complete.') }
            if ($stderrTask.Wait(5000)) { $stderr = $stderrTask.Result } else { $failureReasons.Add('STDERR capture did not complete.') }
        }
    }
    catch {
        $failureReasons.Add("Process launch or capture failed: $($_.Exception.Message)")
    }
    finally {
        $stopwatch.Stop()
        if ($null -ne $process) { $process.Dispose() }
        $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        $resolvedIsolation = [System.IO.Path]::GetFullPath($isolationRoot)
        if ($resolvedIsolation.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedIsolation)) {
            Remove-Item -LiteralPath $resolvedIsolation -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($stderr)) { $failureReasons.Add('STDERR contained output.') }

    if ($Script.Role -eq 'CustomComplianceDiscovery') {
        if ($exitCode -ne 0 -and -not $timedOut) { $failureReasons.Add("Custom Compliance discovery exited $exitCode; exit 0 is required.") }
        if (-not (Test-Path -LiteralPath $Script.RulesPath -PathType Leaf)) {
            $failureReasons.Add('ComplianceRules.json is missing.')
        }
        elseif (-not $timedOut) {
            foreach ($contractResult in @(Test-CustomComplianceOutput -StdOut $stdout -RulesPath $Script.RulesPath -PackagePath $Script.PackagePath)) {
                if ($contractResult.Severity -eq 'Failure') { $failureReasons.Add($contractResult.Message) }
            }
        }
    }
    else {
        if ($null -ne $exitCode -and $exitCode -notin @(0, 1)) { $failureReasons.Add("Detection exit code '$exitCode' is invalid; expected 0 or 1.") }
        if ($Script.Role -eq 'Win32Detection' -and $exitCode -eq 0 -and [string]::IsNullOrWhiteSpace($stdout)) { $failureReasons.Add('Win32 detection exited 0 without STDOUT.') }
        if ($failureReasons.Count -eq 0 -and $exitCode -eq 1 -and $stdout -match $warningPattern) { $warningReasons.Add('Detection exited 1 cleanly, but its output contains failure-like wording.') }
    }

    $status = if ($failureReasons.Count -gt 0) { 'Failed' } elseif ($warningReasons.Count -gt 0) { 'Warning' } else { 'Passed' }
    return New-SmokeResult -Script $Script -Status $status -ExitCode $exitCode -DurationMs ([math]::Round($stopwatch.Elapsed.TotalMilliseconds)) -TimedOut $timedOut -FailureReasons @($failureReasons.ToArray()) -WarningReasons @($warningReasons.ToArray()) -StdOut $stdout -StdErr $stderr
}

function Write-SmokeSummary {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$Results, [Parameter(Mandatory = $true)][string]$Path)

    $passed = @($Results | Where-Object Status -eq 'Passed').Count
    $warnings = @($Results | Where-Object Status -eq 'Warning')
    $failures = @($Results | Where-Object Status -eq 'Failed')
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Safe Detection Smoke Summary')
    $lines.Add('')
    $lines.Add("- Discovered: $($Results.Count)")
    $lines.Add("- Passed: $passed")
    $lines.Add("- Warnings: $($warnings.Count)")
    $lines.Add("- Failures: $($failures.Count)")
    $lines.Add("- Timeout: $TimeoutSeconds seconds")
    $lines.Add('- Isolation: temporary ProgramData, LOCALAPPDATA, and APPDATA per process')
    $lines.Add('')
    $lines.Add('Only `Detect.ps1` and `Discover.ps1` are eligible. Action scripts cannot be selected by this runner.')
    foreach ($item in @($failures + $warnings | Select-Object -First 20)) {
        $reason = @($item.FailureReasons + $item.WarningReasons) -join '; '
        $lines.Add("- **$($item.Status)** ``$($item.RelativePath)`` - $reason")
    }
    [System.IO.File]::WriteAllText($Path, (($lines -join [Environment]::NewLine) + [Environment]::NewLine), (New-Object System.Text.UTF8Encoding($false)))
}

if (-not (Test-Path -LiteralPath $powershellPath -PathType Leaf)) { throw "64-bit Windows PowerShell 5.1 was not found at '$powershellPath'." }
if (-not (Test-Path -LiteralPath $OutputRoot -PathType Container)) { New-Item -Path $OutputRoot -ItemType Directory -Force | Out-Null }

$scripts = @(Get-SafeSmokeScripts)
$results = New-Object System.Collections.Generic.List[object]
$index = 0
foreach ($script in $scripts) {
    $index++
    if ($ListOnly) {
        $results.Add((New-SmokeResult -Script $script -Status 'Listed' -ExitCode $null))
        continue
    }
    if (-not $SummaryOnly) { Write-Output "[$index/$($scripts.Count)] Running $($script.RelativePath)" }
    $result = Invoke-SafeSmokeScript -Script $script
    $results.Add($result)
    if (-not $SummaryOnly -or $result.Status -ne 'Passed') { Write-Output "[$index/$($scripts.Count)] $($result.Status) ExitCode=$($result.ExitCode) DurationMs=$($result.DurationMs) $($script.RelativePath)" }
}

$resultArray = @($results.ToArray())
Write-ValidationResultFile -Path $jsonReportPath -InputObject $resultArray
if ($resultArray.Count -gt 0) { $resultArray | Export-Csv -LiteralPath $csvReportPath -NoTypeInformation -Encoding UTF8 } else { Set-Content -LiteralPath $csvReportPath -Value '' -Encoding UTF8 }
Write-SmokeSummary -Results $resultArray -Path $summaryReportPath

$failures = @($resultArray | Where-Object Status -eq 'Failed')
$warnings = @($resultArray | Where-Object Status -eq 'Warning')
Write-Output "Safe smoke totals: Discovered=$($resultArray.Count); Warnings=$($warnings.Count); Failures=$($failures.Count)."

if (-not [string]::IsNullOrWhiteSpace($ResultPath)) {
    $ruleResults = New-Object System.Collections.Generic.List[object]
    foreach ($item in $resultArray) {
        foreach ($reason in @($item.FailureReasons)) { $ruleResults.Add((New-ValidationRuleResult -RuleId 'Smoke.OutputContract' -Severity Failure -Message $reason -PackagePath $item.PackagePath -File $item.RelativePath)) }
        foreach ($reason in @($item.WarningReasons)) { $ruleResults.Add((New-ValidationRuleResult -RuleId 'Smoke.Review' -Severity Warning -Message $reason -PackagePath $item.PackagePath -File $item.RelativePath)) }
    }
    if ($ruleResults.Count -eq 0) { $ruleResults.Add((New-ValidationRuleResult -RuleId 'Smoke.Valid' -Severity Pass -Message "$($resultArray.Count) safe read-only scripts satisfied their runtime contract.")) }
    $structured = [ordered]@{
        Validator = 'SafeSmoke'
        PackageCount = @($resultArray.PackagePath | Sort-Object -Unique).Count
        Counts = [ordered]@{ Pass = @($resultArray | Where-Object Status -in @('Passed', 'Listed')).Count; Warning = $warnings.Count; Failure = $failures.Count }
        Results = @($ruleResults.ToArray())
    }
    Write-ValidationResultFile -Path $ResultPath -InputObject $structured
}

if ($failures.Count -gt 0) { exit 1 }
exit 0
