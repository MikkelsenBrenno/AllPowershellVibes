<#
.SYNOPSIS
    Smoke-tests Intune detection scripts.

.DESCRIPTION
    Local maintainer tool for this Intune script library. The script discovers
    remediation and Win32 detection scripts, runs each detection in a fresh
    64-bit Windows PowerShell 5.1 process, and writes JSON, CSV, and Markdown
    reports under the configured output folder.

.NOTES
    Name:        Test-DetectionSmoke.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     Local maintainer
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateSet('AllDetect', 'Remediation', 'Win32')]
    [string]$Scope = 'AllDetect',

    [ValidateRange(5, 3600)]
    [int]$TimeoutSeconds = 60,

    [ValidateRange(1, 10000)]
    [int]$MaxScripts,

    [switch]$ListOnly,

    [string]$OutputRoot = (Join-Path -Path (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path -ChildPath 'output'),

    [string]$RepositoryRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path
)

$ErrorActionPreference = 'Stop'

$maxScriptsSpecified = $PSBoundParameters.ContainsKey('MaxScripts')
$powershellPath = Join-Path -Path $env:WINDIR -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
$programDataLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$jsonReportPath = Join-Path -Path $OutputRoot -ChildPath 'detection-smoke-results.json'
$csvReportPath = Join-Path -Path $OutputRoot -ChildPath 'detection-smoke-results.csv'
$summaryReportPath = Join-Path -Path $OutputRoot -ChildPath 'detection-smoke-summary.md'
$warningPattern = '(?i)\b(failed|exception|access denied|could not be validated)\b'

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

function Get-DetectionScripts {
    $items = New-Object System.Collections.Generic.List[object]

    if ($Scope -eq 'AllDetect' -or $Scope -eq 'Remediation') {
        $root = Join-Path -Path $RepositoryRoot -ChildPath 'Detection-Remediation'
        $files = @(Get-ChildItem -Path (Join-Path -Path $root -ChildPath '*\*\Detect.ps1') -File -ErrorAction SilentlyContinue | Sort-Object FullName)

        foreach ($file in $files) {
            $packageFolder = $file.Directory
            $purposeFolder = $packageFolder.Parent
            $items.Add([pscustomobject]@{
                    Workload = 'Detection-Remediation'
                    Purpose = $purposeFolder.Name
                    PackageName = $packageFolder.Name
                    ScriptPath = $file.FullName
                    RelativePath = Get-RelativePath -BasePath $RepositoryRoot -Path $file.FullName
                    WorkingDirectory = $packageFolder.FullName
                })
        }
    }

    if ($Scope -eq 'AllDetect' -or $Scope -eq 'Win32') {
        $root = Join-Path -Path $RepositoryRoot -ChildPath 'Win32-Packaged-Scripts'
        $files = @(Get-ChildItem -Path (Join-Path -Path $root -ChildPath '*\*\Detect.ps1') -File -ErrorAction SilentlyContinue | Sort-Object FullName)

        foreach ($file in $files) {
            $packageFolder = $file.Directory
            $purposeFolder = $packageFolder.Parent
            $items.Add([pscustomobject]@{
                    Workload = 'Win32-Packaged-Scripts'
                    Purpose = $purposeFolder.Name
                    PackageName = $packageFolder.Name
                    ScriptPath = $file.FullName
                    RelativePath = Get-RelativePath -BasePath $RepositoryRoot -Path $file.FullName
                    WorkingDirectory = $packageFolder.FullName
                })
        }
    }

    $ordered = @($items | Sort-Object Workload, Purpose, PackageName)

    if ($maxScriptsSpecified) {
        return @($ordered | Select-Object -First $MaxScripts)
    }

    return $ordered
}

function New-ListOnlyResult {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Script
    )

    return [pscustomobject]@{
        Workload = $Script.Workload
        Purpose = $Script.Purpose
        PackageName = $Script.PackageName
        RelativePath = $Script.RelativePath
        ScriptPath = $Script.ScriptPath
        WorkingDirectory = $Script.WorkingDirectory
        Status = 'Listed'
        Passed = $null
        Warning = $false
        TimedOut = $false
        ExitCode = $null
        DurationMs = $null
        FailureReasons = @()
        WarningReasons = @()
        StdOut = ''
        StdErr = ''
        OutputPreview = ''
    }
}

function Invoke-DetectionScript {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Script
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $stdout = ''
    $stderr = ''
    $exitCode = $null
    $timedOut = $false
    $failureReasons = New-Object System.Collections.Generic.List[string]
    $warningReasons = New-Object System.Collections.Generic.List[string]
    $process = $null

    try {
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $powershellPath
        $startInfo.Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ""$($Script.ScriptPath)"""
        $startInfo.WorkingDirectory = $Script.WorkingDirectory
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo

        if (-not $process.Start()) {
            $failureReasons.Add('PowerShell process failed to start.')
        }
        else {
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            $completed = $process.WaitForExit($TimeoutSeconds * 1000)

            if (-not $completed) {
                $timedOut = $true
                $failureReasons.Add("Timed out after $TimeoutSeconds second(s).")

                try {
                    $process.Kill()
                    if (-not $process.WaitForExit(5000)) {
                        $failureReasons.Add('Timed-out PowerShell process did not exit after kill request.')
                    }
                }
                catch {
                    $failureReasons.Add("Timed-out PowerShell process could not be killed. $($_.Exception.Message)")
                }
            }
            else {
                $process.WaitForExit()
                $exitCode = $process.ExitCode
            }

            if ($stdoutTask.Wait(5000)) {
                $stdout = $stdoutTask.Result
            }
            else {
                $failureReasons.Add('STDOUT capture did not complete after process exit.')
            }

            if ($stderrTask.Wait(5000)) {
                $stderr = $stderrTask.Result
            }
            else {
                $failureReasons.Add('STDERR capture did not complete after process exit.')
            }
        }
    }
    catch {
        $failureReasons.Add("Process launch or capture failed. $($_.Exception.Message)")
    }
    finally {
        $stopwatch.Stop()

        if ($null -ne $process) {
            $process.Dispose()
        }
    }

    if ($null -eq $exitCode -and -not $timedOut -and $failureReasons.Count -eq 0) {
        $failureReasons.Add('Process ended without an exit code.')
    }

    if ($null -ne $exitCode -and $exitCode -notin @(0, 1)) {
        $failureReasons.Add("Exit code '$exitCode' is not valid for an Intune detection smoke test.")
    }

    if (-not [string]::IsNullOrWhiteSpace($stderr)) {
        $failureReasons.Add('PowerShell stderr contained output, which may indicate an unhandled error.')
    }

    if ($Script.Workload -eq 'Win32-Packaged-Scripts' -and $exitCode -eq 0 -and [string]::IsNullOrWhiteSpace($stdout)) {
        $failureReasons.Add('Win32 detection exited 0 without STDOUT. Intune may not treat the app as detected.')
    }

    if ($failureReasons.Count -eq 0 -and $exitCode -eq 1 -and $stdout -match $warningPattern) {
        $warningReasons.Add('Detection exited 1 cleanly, but output contains failure-like wording that should be reviewed.')
    }

    $status = if ($failureReasons.Count -gt 0) {
        'Failed'
    }
    elseif ($warningReasons.Count -gt 0) {
        'Warning'
    }
    else {
        'Passed'
    }

    $combinedOutput = (($stdout, $stderr) -join [Environment]::NewLine).Trim()
    $preview = $combinedOutput
    if ($preview.Length -gt 500) {
        $preview = $preview.Substring(0, 500) + '...'
    }

    return [pscustomobject]@{
        Workload = $Script.Workload
        Purpose = $Script.Purpose
        PackageName = $Script.PackageName
        RelativePath = $Script.RelativePath
        ScriptPath = $Script.ScriptPath
        WorkingDirectory = $Script.WorkingDirectory
        Status = $status
        Passed = ($failureReasons.Count -eq 0)
        Warning = ($warningReasons.Count -gt 0)
        TimedOut = $timedOut
        ExitCode = $exitCode
        DurationMs = [math]::Round($stopwatch.Elapsed.TotalMilliseconds, 0)
        FailureReasons = @($failureReasons.ToArray())
        WarningReasons = @($warningReasons.ToArray())
        StdOut = $stdout.Trim()
        StdErr = $stderr.Trim()
        OutputPreview = $preview
    }
}

function New-CsvRows {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results
    )

    foreach ($result in $Results) {
        [pscustomobject]@{
            Workload = $result.Workload
            Purpose = $result.Purpose
            PackageName = $result.PackageName
            RelativePath = $result.RelativePath
            Status = $result.Status
            Passed = $result.Passed
            Warning = $result.Warning
            TimedOut = $result.TimedOut
            ExitCode = $result.ExitCode
            DurationMs = $result.DurationMs
            FailureReasons = ($result.FailureReasons -join '; ')
            WarningReasons = ($result.WarningReasons -join '; ')
            OutputPreview = $result.OutputPreview
        }
    }
}

function Add-MarkdownTable {
    param(
        [object]$Lines,

        [Parameter(Mandatory = $true)]
        [array]$Rows,

        [Parameter(Mandatory = $true)]
        [string]$FirstHeader,

        [Parameter(Mandatory = $true)]
        [string]$SecondHeader
    )

    $Lines.Add("| $FirstHeader | $SecondHeader |")
    $Lines.Add('| --- | ---: |')

    foreach ($row in $Rows) {
        $Lines.Add("| $($row.Name) | $($row.Count) |")
    }
}

function Test-ProgramDataLogRoot {
    $result = [pscustomobject]@{
        Path = $programDataLogRoot
        Writable = $false
        Message = 'Not tested during list-only discovery.'
    }

    if ($ListOnly) {
        return $result
    }

    $probeFile = Join-Path -Path $programDataLogRoot -ChildPath ('.smoke-test-{0}.tmp' -f ([guid]::NewGuid().ToString('N')))

    try {
        if (-not (Test-Path -LiteralPath $programDataLogRoot -PathType Container)) {
            New-Item -Path $programDataLogRoot -ItemType Directory -Force | Out-Null
        }

        Set-Content -LiteralPath $probeFile -Value 'Detection smoke test log root probe.' -Encoding UTF8
        Remove-Item -LiteralPath $probeFile -Force

        $result.Writable = $true
        $result.Message = 'Writable.'
    }
    catch {
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Write-SummaryReport {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $executed = @($Results | Where-Object { $_.Status -ne 'Listed' })
    $failures = @($Results | Where-Object { $_.Status -eq 'Failed' })
    $warnings = @($Results | Where-Object { $_.Status -eq 'Warning' })
    $passed = @($Results | Where-Object { $_.Status -eq 'Passed' })
    $maxScriptsDisplay = if ($maxScriptsSpecified) { $MaxScripts } else { 'All' }
    $listOnlyDisplay = [bool]$ListOnly
    $logWritableDisplay = if ($programDataLogCheck.Writable) { 'True' } else { 'False' }

    $lines.Add('# Detection Smoke Test Summary')
    $lines.Add('')
    $lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $lines.Add('')
    $lines.Add('## Run Settings')
    $lines.Add('')
    $lines.Add("| Setting | Value |")
    $lines.Add("| --- | --- |")
    $lines.Add("| Scope | $Scope |")
    $lines.Add("| TimeoutSeconds | $TimeoutSeconds |")
    $lines.Add("| MaxScripts | $maxScriptsDisplay |")
    $lines.Add("| ListOnly | $listOnlyDisplay |")
    $lines.Add("| PowerShell | $powershellPath |")
    $lines.Add("| ProgramDataLogRoot | $($programDataLogCheck.Path) |")
    $lines.Add("| ProgramDataLogRootWritable | $logWritableDisplay |")
    $lines.Add("| ProgramDataLogRootMessage | $($programDataLogCheck.Message -replace '\|', '/') |")
    $lines.Add('')
    $lines.Add('## Results')
    $lines.Add('')
    $lines.Add("| Metric | Count |")
    $lines.Add("| --- | ---: |")
    $lines.Add("| Discovered | $($Results.Count) |")
    $lines.Add("| Executed | $($executed.Count) |")
    $lines.Add("| Passed | $($passed.Count) |")
    $lines.Add("| Review warnings | $($warnings.Count) |")
    $lines.Add("| Hard failures | $($failures.Count) |")
    $lines.Add('')

    $byWorkload = @($Results | Group-Object -Property Workload | Sort-Object Name)
    $lines.Add('## By Workload')
    $lines.Add('')
    Add-MarkdownTable -Lines $lines -Rows $byWorkload -FirstHeader 'Workload' -SecondHeader 'Count'
    $lines.Add('')

    $byStatus = @($Results | Group-Object -Property Status | Sort-Object Name)
    $lines.Add('## By Status')
    $lines.Add('')
    Add-MarkdownTable -Lines $lines -Rows $byStatus -FirstHeader 'Status' -SecondHeader 'Count'
    $lines.Add('')

    if ($failures.Count -gt 0) {
        $lines.Add('## Hard Failures')
        $lines.Add('')
        $lines.Add('| Script | ExitCode | Reason |')
        $lines.Add('| --- | ---: | --- |')

        foreach ($failure in @($failures | Select-Object -First 50)) {
            $relativePath = $failure.RelativePath -replace '\|', '/'
            $reason = ($failure.FailureReasons -join '; ') -replace '\|', '/'
            $lines.Add("| ``$relativePath`` | $($failure.ExitCode) | $reason |")
        }

        if ($failures.Count -gt 50) {
            $lines.Add('')
            $lines.Add("Only the first 50 hard failures are shown. See $csvReportPath or $jsonReportPath for the full list.")
        }

        $lines.Add('')
    }

    if ($warnings.Count -gt 0) {
        $lines.Add('## Review Warnings')
        $lines.Add('')
        $lines.Add('| Script | ExitCode | Reason |')
        $lines.Add('| --- | ---: | --- |')

        foreach ($warning in @($warnings | Select-Object -First 50)) {
            $relativePath = $warning.RelativePath -replace '\|', '/'
            $reason = ($warning.WarningReasons -join '; ') -replace '\|', '/'
            $lines.Add("| ``$relativePath`` | $($warning.ExitCode) | $reason |")
        }

        if ($warnings.Count -gt 50) {
            $lines.Add('')
            $lines.Add("Only the first 50 review warnings are shown. See $csvReportPath or $jsonReportPath for the full list.")
        }

        $lines.Add('')
    }

    $lines.Add('## Notes')
    $lines.Add('')
    $lines.Add('- This is a smoke test. It does not prove tenant policy compliance.')
    $lines.Add('- Remediation detections can exit `1` for normal noncompliance.')
    $lines.Add('- Win32 detections must write STDOUT when exiting `0`.')
    $lines.Add('- Script logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs`.')

    Set-Content -LiteralPath $Path -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
}

if (-not (Test-Path -LiteralPath $powershellPath -PathType Leaf)) {
    throw "64-bit Windows PowerShell 5.1 was not found at '$powershellPath'."
}

if (-not (Test-Path -LiteralPath $OutputRoot)) {
    New-Item -Path $OutputRoot -ItemType Directory -Force | Out-Null
}

$scripts = @(Get-DetectionScripts)
$programDataLogCheck = Test-ProgramDataLogRoot
$results = New-Object System.Collections.Generic.List[object]
$scriptIndex = 0
$scriptTotal = [math]::Max($scripts.Count, 1)

foreach ($script in $scripts) {
    $scriptIndex++

    if ($ListOnly) {
        $results.Add((New-ListOnlyResult -Script $script))
    }
    else {
        Write-Output "[$scriptIndex/$($scripts.Count)] Running $($script.RelativePath)"
        Write-Progress -Activity 'Detection smoke test' -Status $script.RelativePath -PercentComplete (($results.Count / $scriptTotal) * 100)

        $result = Invoke-DetectionScript -Script $script
        $results.Add($result)

        Write-Output "[$scriptIndex/$($scripts.Count)] $($result.Status) ExitCode=$($result.ExitCode) DurationMs=$($result.DurationMs) $($script.RelativePath)"
    }
}

Write-Progress -Activity 'Detection smoke test' -Completed

$resultArray = @($results.ToArray())
$resultArray | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonReportPath -Encoding UTF8
New-CsvRows -Results $resultArray | Export-Csv -LiteralPath $csvReportPath -NoTypeInformation -Encoding UTF8
Write-SummaryReport -Results $resultArray -Path $summaryReportPath

$failures = @($resultArray | Where-Object { $_.Status -eq 'Failed' })
$warnings = @($resultArray | Where-Object { $_.Status -eq 'Warning' })

Write-Output "Detection smoke test report written to '$summaryReportPath'."
Write-Output "Discovered: $($resultArray.Count); HardFailures: $($failures.Count); ReviewWarnings: $($warnings.Count)."

if ($failures.Count -gt 0) {
    exit 1
}

exit 0
