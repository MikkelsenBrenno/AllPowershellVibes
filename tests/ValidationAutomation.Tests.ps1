#Requires -Version 5.1

BeforeAll {
    $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:ModulePath = Join-Path $script:RepositoryRoot 'tools\IntuneLibrary.Validation.psm1'
    $script:CurrentEngine = (Get-Process -Id $PID).Path
    Import-Module $script:ModulePath -Force

    function Write-TestFile {
        param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content)
        $parent = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }
        [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
    }

    function New-TestScriptInfo {
        param(
            [Parameter(Mandatory = $true)][string]$Workload,
            [Parameter(Mandatory = $true)][string]$Status,
            [Parameter(Mandatory = $true)][string]$HasRemediation,
            [string]$HasUninstall = 'No',
            [string]$EvidenceType = 'DirectEvidence',
            [string]$EvidenceSource = 'Service',
            [string]$EvidenceReview = 'Reviewed'
        )
        [ordered]@{
            Name = 'Fixture package'
            Workload = $Workload
            Purpose = 'Security'
            Status = $Status
            Context = 'System'
            Requires64BitPowerShell = 'Recommended'
            HasRemediation = $HasRemediation
            HasUninstall = $HasUninstall
            TeamsAlertReady = 'No'
            WritesTo = 'Fixture only'
            Reboot = 'No'
            Risk = 'Low'
            DetectionEvidenceType = $EvidenceType
            DetectionEvidenceSource = $EvidenceSource
            DetectionReviewStatus = $EvidenceReview
            PortabilityReviewStatus = 'Reviewed'
            PortabilityRiskLevel = 'None'
            PortabilityRiskAreas = @()
            PortabilityNotes = 'No portability risks detected by static audit.'
            Summary = 'Temporary validation fixture.'
            Tags = @('Test')
        } | ConvertTo-Json -Depth 8
    }

    function New-MiniRepository {
        param([Parameter(Mandatory = $true)][string]$Root)

        $pilotReadme = @'
# Fixture package

## Pilot Validation

Run the fixture in an isolated test repository.

## Microsoft References

- https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations
'@

        foreach ($workload in @('Detection-Remediation', 'Custom-Compliance', 'Intune-Platform-Scripts', 'Win32-Packaged-Scripts')) {
            New-Item -Path (Join-Path $Root "$workload\Security") -ItemType Directory -Force | Out-Null
        }

        $remediation = Join-Path $Root 'Detection-Remediation\Security\Fixture-Remediation'
        Write-TestFile -Path (Join-Path $remediation 'ScriptInfo.json') -Content (New-TestScriptInfo -Workload 'Detection and Remediation' -Status PilotReady -HasRemediation Yes)
        Write-TestFile -Path (Join-Path $remediation 'README.md') -Content $pilotReadme
        Write-TestFile -Path (Join-Path $remediation 'Detect.ps1') -Content @'
# CONFIGURATION
$ScriptPackageName = 'Fixture-Remediation'
$ScriptName = 'Detect'
$ExpectedService = 'Spooler'
$AllowedValues = @('One', 'Two')
$Enabled = $true
$RetryCount = 3
$OptionalValue = $null
# LOGGING
function Write-ScriptMetadata {}
# =========================
# MAIN
# =========================
$service = Get-Service -Name $ExpectedService -ErrorAction SilentlyContinue
if ($null -ne $service) {
    exit 0
}
exit 1
'@
        Write-TestFile -Path (Join-Path $remediation 'Remediate.ps1') -Content @'
# CONFIGURATION
$ScriptPackageName = 'Fixture-Remediation'
$ScriptName = 'Remediate'
# LOGGING
function Write-ScriptMetadata {}
# =========================
# MAIN
# =========================
if ($false) {
    exit 1
}
exit 0
'@

        $compliance = Join-Path $Root 'Custom-Compliance\Security\Fixture-Compliance'
        Write-TestFile -Path (Join-Path $compliance 'ScriptInfo.json') -Content (New-TestScriptInfo -Workload 'Custom Compliance' -Status PilotReady -HasRemediation No)
        Write-TestFile -Path (Join-Path $compliance 'README.md') -Content $pilotReadme
        Write-TestFile -Path (Join-Path $compliance 'Discover.ps1') -Content @'
# CONFIGURATION
$ScriptPackageName = 'Fixture-Compliance'
$ScriptName = 'Discover'
# LOGGING
function Write-ScriptMetadata {}
# MAIN
[ordered]@{ IsCompliant = $true } | ConvertTo-Json -Compress | Write-Output
exit 0
'@
        Write-TestFile -Path (Join-Path $compliance 'ComplianceRules.json') -Content '{"Rules":[{"SettingName":"IsCompliant","Operator":"IsEquals","DataType":"Boolean","Operand":true,"MoreInfoUrl":"https://example.invalid","RemediationStrings":[{"Language":"en_US","Title":"Fix","Description":"Fix it"}]}]}'

        $platform = Join-Path $Root 'Intune-Platform-Scripts\Security\Fixture-Platform'
        Write-TestFile -Path (Join-Path $platform 'ScriptInfo.json') -Content (New-TestScriptInfo -Workload 'Intune Platform Scripts' -Status PilotReady -HasRemediation 'N/A' -EvidenceType 'N/A' -EvidenceSource 'No detection script for this workload' -EvidenceReview NotApplicable)
        Write-TestFile -Path (Join-Path $platform 'README.md') -Content $pilotReadme
        Write-TestFile -Path (Join-Path $platform 'Run.ps1') -Content @'
# CONFIGURATION
$ScriptPackageName = 'Fixture-Platform'
$ScriptName = 'Run'
# LOGGING
function Write-ScriptMetadata {}
# MAIN
Write-Output 'Platform fixture'
exit 0
'@

        $win32 = Join-Path $Root 'Win32-Packaged-Scripts\Security\Fixture-Win32'
        Write-TestFile -Path (Join-Path $win32 'ScriptInfo.json') -Content (New-TestScriptInfo -Workload 'Win32 Packaged Scripts' -Status PilotReady -HasRemediation 'N/A' -HasUninstall Yes -EvidenceType PackageMarker -EvidenceSource 'Win32 package install/version marker')
        Write-TestFile -Path (Join-Path $win32 'README.md') -Content $pilotReadme
        Write-TestFile -Path (Join-Path $win32 'Install.ps1') -Content "# CONFIGURATION`n`$ScriptPackageName='Fixture-Win32'`n`$ScriptName='Install'`n# LOGGING`nfunction Write-ScriptMetadata {}`n# MAIN`nexit 0"
        Write-TestFile -Path (Join-Path $win32 'Detect.ps1') -Content "# CONFIGURATION`n`$ScriptPackageName='Fixture-Win32'`n`$ScriptName='Detect'`n`$PackageVersion='1.0'`n# LOGGING`nfunction Write-ScriptMetadata {}`n# MAIN`nif (`$PackageVersion) { Write-Output 'Detected'; exit 0 }`nexit 1"
        Write-TestFile -Path (Join-Path $win32 'Uninstall.ps1') -Content "# CONFIGURATION`n`$ScriptPackageName='Fixture-Win32'`n`$ScriptName='Uninstall'`n# LOGGING`nfunction Write-ScriptMetadata {}`n# MAIN`nexit 0"
    }

    $script:FixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('intune-validation-pester-' + [guid]::NewGuid().ToString('N'))
    New-Item -Path $script:FixtureRoot -ItemType Directory -Force | Out-Null
    New-MiniRepository -Root $script:FixtureRoot
}

AfterAll {
    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    $fixturePath = [System.IO.Path]::GetFullPath($script:FixtureRoot)
    if ($fixturePath.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $fixturePath)) {
        Remove-Item -LiteralPath $fixturePath -Recurse -Force
    }
}

Describe 'Changed package scope resolution' {
    It 'maps repository files to their three-segment package path' {
        Get-ValidationPackagePath 'Detection-Remediation/Security/Package/Detect.ps1' | Should -Be 'Detection-Remediation/Security/Package'
        Get-ValidationPackagePath 'README.md' | Should -BeNullOrEmpty
    }

    It 'keeps both source and destination paths for a rename' {
        $result = Resolve-ValidationScope -Scope Changed -RepositoryRoot $script:FixtureRoot -BaseRef ignored -HeadRef ignored -NameStatusLines @("R100`tDetection-Remediation/Security/Old/Detect.ps1`tDetection-Remediation/Security/Fixture-Remediation/Detect.ps1")
        $result.ChangedPackagePaths | Should -Contain 'Detection-Remediation/Security/Old'
        $result.ChangedPackagePaths | Should -Contain 'Detection-Remediation/Security/Fixture-Remediation'
        $result.DeletedOrMissingPackagePaths | Should -Contain 'Detection-Remediation/Security/Old'
    }

    It 'tracks a deleted package while selecting no missing directory' {
        $result = Resolve-ValidationScope -Scope Changed -RepositoryRoot $script:FixtureRoot -BaseRef ignored -HeadRef ignored -NameStatusLines @("D`tCustom-Compliance/Security/Removed/Discover.ps1")
        $result.ChangedPackagePaths | Should -Contain 'Custom-Compliance/Security/Removed'
        $result.PackagePaths | Should -Not -Contain 'Custom-Compliance/Security/Removed'
    }

    It 'escalates shared validation changes and records the path' {
        $result = Resolve-ValidationScope -Scope Changed -RepositoryRoot $script:FixtureRoot -BaseRef ignored -HeadRef ignored -NameStatusLines @("M`ttools/IntuneLibrary.Validation.psm1")
        $result.EffectiveScope | Should -Be Full
        $result.EscalationReason | Should -Match 'IntuneLibrary.Validation.psm1'
    }

    It 'escalates when more than 100 packages change' {
        $changes = 1..101 | ForEach-Object { "M`tDetection-Remediation/Security/Package-$_/Detect.ps1" }
        $result = Resolve-ValidationScope -Scope Changed -RepositoryRoot $script:FixtureRoot -BaseRef ignored -HeadRef ignored -NameStatusLines $changes
        $result.EffectiveScope | Should -Be Full
        $result.EscalationReason | Should -Match 'exceeds threshold 100'
    }

    It 'discovers one temporary package per workload' {
        $inventory = Get-ValidationPackageInventory -RepositoryRoot $script:FixtureRoot
        @($inventory | Where-Object { $_ -match 'Fixture-(Remediation|Compliance|Platform|Win32)$' }).Count | Should -Be 4
    }
}

Describe 'Structured result serialization' {
    It 'writes stable JSON with rule-level fields' {
        $path = Join-Path $script:FixtureRoot 'result.json'
        $input = [ordered]@{ Validator = 'Unit'; Counts = [ordered]@{ Pass = 1; Warning = 0; Failure = 0 }; Results = @((New-ValidationRuleResult -RuleId Unit.Pass -Severity Pass -Message 'ok')) }
        Write-ValidationResultFile -Path $path -InputObject $input
        $first = [System.IO.File]::ReadAllText($path)
        Write-ValidationResultFile -Path $path -InputObject $input
        [System.IO.File]::ReadAllText($path) | Should -BeExactly $first
        ($first | ConvertFrom-Json).Results[0].RuleId | Should -Be 'Unit.Pass'
    }
}

Describe 'Tenant profile literal assertions' {
    It 'reads literal strings, numbers, booleans, nulls, and arrays without execution' {
        $scriptPath = Join-Path $script:FixtureRoot 'Detection-Remediation\Security\Fixture-Remediation\Detect.ps1'
        Get-ValidationConfigurationValue -ScriptPath $scriptPath -Variable ExpectedService | Should -Be 'Spooler'
        Get-ValidationConfigurationValue -ScriptPath $scriptPath -Variable RetryCount | Should -Be 3
        Get-ValidationConfigurationValue -ScriptPath $scriptPath -Variable Enabled | Should -BeTrue
        Get-ValidationConfigurationValue -ScriptPath $scriptPath -Variable OptionalValue | Should -BeNullOrEmpty
        @(Get-ValidationConfigurationValue -ScriptPath $scriptPath -Variable AllowedValues) | Should -Be @('One', 'Two')
    }

    It 'rejects a computed configuration value' {
        $scriptPath = Join-Path $script:FixtureRoot 'computed.ps1'
        Write-TestFile $scriptPath "# CONFIGURATION`n`$Computed = Join-Path 'a' 'b'`n# LOGGING"
        { Get-ValidationConfigurationValue -ScriptPath $scriptPath -Variable Computed } | Should -Throw '*computed or unsupported*'
    }

    It 'validates a matching tenant profile' {
        $profilePath = Join-Path $script:FixtureRoot 'tenant-profile.valid.json'
        Write-TestFile $profilePath '{"SchemaVersion":"1.0","Packages":[{"Path":"Detection-Remediation/Security/Fixture-Remediation","AllowedStatuses":["PilotReady","Validated"],"ExpectedContext":"System","ConfigurationAssertions":[{"Script":"Detect.ps1","Variable":"ExpectedService","Equals":"Spooler"},{"Script":"Detect.ps1","Variable":"AllowedValues","Equals":["One","Two"]}]}]}'
        $results = @(Test-TenantValidationProfile -ProfilePath $profilePath -RepositoryRoot $script:FixtureRoot)
        @($results | Where-Object Severity -eq Failure).Count | Should -Be 0
    }

    It 'rejects malformed, duplicate, nonexistent, status-mismatched, and unknown profile values' {
        $malformed = Join-Path $script:FixtureRoot 'tenant-profile.malformed.json'
        Write-TestFile $malformed '{bad'
        @(Test-TenantValidationProfile -ProfilePath $malformed -RepositoryRoot $script:FixtureRoot | Where-Object Severity -eq Failure).Count | Should -BeGreaterThan 0

        $invalid = Join-Path $script:FixtureRoot 'tenant-profile.invalid.json'
        Write-TestFile $invalid '{"SchemaVersion":"1.0","Unknown":true,"Packages":[{"Path":"Detection-Remediation/Security/Fixture-Remediation","AllowedStatuses":["Validated"],"ExpectedContext":"User"},{"Path":"Detection-Remediation/Security/Fixture-Remediation","AllowedStatuses":["NotAStatus"],"ExpectedContext":"System"},{"Path":"Custom-Compliance/Security/Missing","AllowedStatuses":["PilotReady"],"ExpectedContext":"System"}]}'
        $results = @(Test-TenantValidationProfile -ProfilePath $invalid -RepositoryRoot $script:FixtureRoot)
        @($results | Where-Object Severity -eq Failure).Count | Should -BeGreaterThan 3
        @($results.RuleId) | Should -Contain 'TenantProfile.DuplicatePath'
        @($results.RuleId) | Should -Contain 'TenantProfile.PackageExists'
        @($results.RuleId) | Should -Contain 'TenantProfile.Status'
    }
}

Describe 'Custom Compliance runtime contract' {
    BeforeAll {
        $script:RulesPath = Join-Path $script:FixtureRoot 'Custom-Compliance\Security\Fixture-Compliance\ComplianceRules.json'
    }

    It 'matches discovery keys and types to the rule file' {
        $results = @(Test-CustomComplianceOutput -StdOut '{"IsCompliant":true}' -RulesPath $script:RulesPath -PackagePath 'Custom-Compliance/Security/Fixture-Compliance')
        @($results | Where-Object Severity -eq Failure).Count | Should -Be 0
    }

    It 'rejects malformed JSON, missing keys, invalid types, and extra output lines' {
        @(Test-CustomComplianceOutput -StdOut '{bad' -RulesPath $script:RulesPath | Where-Object Severity -eq Failure).Count | Should -BeGreaterThan 0
        @(Test-CustomComplianceOutput -StdOut '{"Other":true}' -RulesPath $script:RulesPath | Where-Object Severity -eq Failure).Count | Should -BeGreaterThan 0
        @(Test-CustomComplianceOutput -StdOut '{"IsCompliant":"true"}' -RulesPath $script:RulesPath | Where-Object Severity -eq Failure).Count | Should -BeGreaterThan 0
        @(Test-CustomComplianceOutput -StdOut "noise`n{\"IsCompliant\":true}" -RulesPath $script:RulesPath | Where-Object Severity -eq Failure).Count | Should -BeGreaterThan 0
    }

    It 'rejects a rules document with no Rules collection' {
        $emptyRules = Join-Path $script:FixtureRoot 'empty-rules.json'
        Write-TestFile $emptyRules '{}'
        @(Test-CustomComplianceOutput -StdOut '{"IsCompliant":true}' -RulesPath $emptyRules | Where-Object Severity -eq Failure).Count | Should -BeGreaterThan 0
    }
}

Describe 'Existing validator integration with temporary packages' {
    It 'accepts PilotReady documentation with pilot steps and a Microsoft Learn reference' {
        $resultPath = Join-Path $script:FixtureRoot 'pilot-documentation-result.json'
        & $script:CurrentEngine -NoLogo -NoProfile -NonInteractive -File (Join-Path $script:RepositoryRoot 'tools\Test-IntuneWorkloadContracts.ps1') -RepositoryRoot $script:FixtureRoot -PackagePath 'Detection-Remediation/Security/Fixture-Remediation' -SummaryOnly -ResultPath $resultPath
        $result = [System.IO.File]::ReadAllText($resultPath) | ConvertFrom-Json
        $LASTEXITCODE | Should -Be 0 -Because ($result.Results.Message -join '; ')
    }

    It 'blocks promotion when Pilot Validation documentation is missing' {
        $readmePath = Join-Path $script:FixtureRoot 'Detection-Remediation\Security\Fixture-Remediation\README.md'
        $originalReadme = [System.IO.File]::ReadAllText($readmePath)
        $resultPath = Join-Path $script:FixtureRoot 'missing-pilot-documentation-result.json'
        try {
            Write-TestFile -Path $readmePath -Content "# Fixture package`n`nhttps://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations"
            & $script:CurrentEngine -NoLogo -NoProfile -NonInteractive -File (Join-Path $script:RepositoryRoot 'tools\Test-IntuneWorkloadContracts.ps1') -RepositoryRoot $script:FixtureRoot -PackagePath 'Detection-Remediation/Security/Fixture-Remediation' -SummaryOnly -ResultPath $resultPath
            $LASTEXITCODE | Should -Be 1
            $result = [System.IO.File]::ReadAllText($resultPath) | ConvertFrom-Json
            ($result.Results.Message -join ' ') | Should -Match "no 'Pilot Validation' section"
        }
        finally {
            Write-TestFile -Path $readmePath -Content $originalReadme
        }
    }

    It 'requires non-sensitive evidence documentation for Validated status' {
        $scriptInfoPath = Join-Path $script:FixtureRoot 'Detection-Remediation\Security\Fixture-Remediation\ScriptInfo.json'
        $originalScriptInfo = [System.IO.File]::ReadAllText($scriptInfoPath)
        $resultPath = Join-Path $script:FixtureRoot 'missing-validation-evidence-result.json'
        try {
            $scriptInfo = $originalScriptInfo | ConvertFrom-Json
            $scriptInfo.Status = 'Validated'
            Write-TestFile -Path $scriptInfoPath -Content ($scriptInfo | ConvertTo-Json -Depth 8)
            & $script:CurrentEngine -NoLogo -NoProfile -NonInteractive -File (Join-Path $script:RepositoryRoot 'tools\Test-IntuneWorkloadContracts.ps1') -RepositoryRoot $script:FixtureRoot -PackagePath 'Detection-Remediation/Security/Fixture-Remediation' -SummaryOnly -ResultPath $resultPath
            $LASTEXITCODE | Should -Be 1
            $result = [System.IO.File]::ReadAllText($resultPath) | ConvertFrom-Json
            ($result.Results.Message -join ' ') | Should -Match "no 'Validation Evidence' section"
        }
        finally {
            Write-TestFile -Path $scriptInfoPath -Content $originalScriptInfo
        }
    }

    It 'keeps a normal one-package summary below 200 console lines' {
        $resultPath = Join-Path $script:FixtureRoot 'one-package-repository-result.json'
        $console = @(& $script:CurrentEngine -NoLogo -NoProfile -NonInteractive -File (Join-Path $script:RepositoryRoot 'tools\Test-Repository.ps1') -RepositoryRoot $script:RepositoryRoot -PackagePath 'Detection-Remediation/Applications/Clear-Microsoft-Store-Cache-Safely' -SummaryOnly -ResultPath $resultPath)
        $LASTEXITCODE | Should -Be 0
        $console.Count | Should -BeLessThan 200
        $result = [System.IO.File]::ReadAllText($resultPath) | ConvertFrom-Json
        $result.PackageCount | Should -Be 1
    }

    It 'classifies direct evidence and writes a structured result' {
        $output = Join-Path $script:FixtureRoot 'evidence-output'
        $resultPath = Join-Path $script:FixtureRoot 'evidence-structured.json'
        & $script:CurrentEngine -NoLogo -NoProfile -NonInteractive -File (Join-Path $script:RepositoryRoot 'tools\Test-DetectionEvidence.ps1') -RepositoryRoot $script:FixtureRoot -OutputRoot $output -PackagePath 'Detection-Remediation/Security/Fixture-Remediation' -SummaryOnly -ResultPath $resultPath
        $LASTEXITCODE | Should -Be 0
        $detail = [System.IO.File]::ReadAllText((Join-Path $output 'detection-evidence-results.json')) | ConvertFrom-Json
        $detail.DetectionEvidenceType | Should -Be 'DirectEvidence'
        (Test-Path -LiteralPath $resultPath) | Should -BeTrue
    }

    It 'detects mutating Custom Compliance discovery logic' {
        $package = Join-Path $script:FixtureRoot 'Custom-Compliance\Security\Mutating-Discovery'
        Write-TestFile (Join-Path $package 'ScriptInfo.json') (New-TestScriptInfo -Workload 'Custom Compliance' -Status PilotReady -HasRemediation No)
        Write-TestFile (Join-Path $package 'ComplianceRules.json') '{"Rules":[{"SettingName":"IsCompliant","Operator":"IsEquals","DataType":"Boolean","Operand":true,"MoreInfoUrl":"https://example.invalid","RemediationStrings":[{"Language":"en_US","Title":"Fix","Description":"Fix"}]}]}'
        Write-TestFile (Join-Path $package 'Discover.ps1') "# CONFIGURATION`n`$ScriptPackageName='Mutating-Discovery'`n`$ScriptName='Discover'`n# LOGGING`nfunction Write-ScriptMetadata {}`n# =========================`n# MAIN`n# =========================`nSet-Item -Path env:BAD -Value 1`n[ordered]@{IsCompliant=`$true}|ConvertTo-Json -Compress|Write-Output`nexit 0"
        $resultPath = Join-Path $script:FixtureRoot 'mutating-result.json'
        & $script:CurrentEngine -NoLogo -NoProfile -NonInteractive -File (Join-Path $script:RepositoryRoot 'tools\Test-IntuneWorkloadContracts.ps1') -RepositoryRoot $script:FixtureRoot -PackagePath 'Custom-Compliance/Security/Mutating-Discovery' -SummaryOnly -ResultPath $resultPath
        $LASTEXITCODE | Should -Be 1
        $result = [System.IO.File]::ReadAllText($resultPath) | ConvertFrom-Json
        ($result.Results.Message -join ' ') | Should -Match 'change managed state'
    }

    It 'detects remediation detection false-success exit paths' {
        $package = Join-Path $script:FixtureRoot 'Detection-Remediation\Security\False-Success'
        Write-TestFile (Join-Path $package 'ScriptInfo.json') (New-TestScriptInfo -Workload 'Detection and Remediation' -Status PilotReady -HasRemediation Yes)
        Write-TestFile (Join-Path $package 'Detect.ps1') "# CONFIGURATION`n`$ScriptPackageName='False-Success'`n`$ScriptName='Detect'`n# LOGGING`nfunction Write-ScriptMetadata {}`n# MAIN`nexit 0"
        Write-TestFile (Join-Path $package 'Remediate.ps1') "# CONFIGURATION`n`$ScriptPackageName='False-Success'`n`$ScriptName='Remediate'`n# LOGGING`nfunction Write-ScriptMetadata {}`n# MAIN`nexit 0"
        $resultPath = Join-Path $script:FixtureRoot 'false-success-result.json'
        & $script:CurrentEngine -NoLogo -NoProfile -NonInteractive -File (Join-Path $script:RepositoryRoot 'tools\Test-IntuneWorkloadContracts.ps1') -RepositoryRoot $script:FixtureRoot -PackagePath 'Detection-Remediation/Security/False-Success' -SummaryOnly -ResultPath $resultPath
        $LASTEXITCODE | Should -Be 1
        $result = [System.IO.File]::ReadAllText($resultPath) | ConvertFrom-Json
        ($result.Results.Message -join ' ') | Should -Match "no explicit 'exit 1' path"
    }

    It 'refuses mutating discovery logic before smoke execution' -Skip:([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
        $package = Join-Path $script:FixtureRoot 'Custom-Compliance\Security\Unsafe-Smoke'
        Write-TestFile (Join-Path $package 'ScriptInfo.json') (New-TestScriptInfo -Workload 'Custom Compliance' -Status Example -HasRemediation No)
        Write-TestFile (Join-Path $package 'ComplianceRules.json') '{"Rules":[{"SettingName":"IsCompliant","Operator":"IsEquals","DataType":"Boolean","Operand":true,"MoreInfoUrl":"https://example.invalid","RemediationStrings":[{"Language":"en_US","Title":"Fix","Description":"Fix"}]}]}'
        Write-TestFile (Join-Path $package 'Discover.ps1') "# CONFIGURATION`n`$ScriptPackageName='Unsafe-Smoke'`n`$ScriptName='Discover'`n# LOGGING`nfunction Write-ScriptMetadata {}`n# =========================`n# MAIN`n# =========================`nSet-Item -Path env:SHOULD_NOT_RUN -Value 1`n[ordered]@{IsCompliant=`$true}|ConvertTo-Json -Compress|Write-Output`nexit 0"
        $output = Join-Path $script:FixtureRoot 'unsafe-smoke-output'
        $resultPath = Join-Path $script:FixtureRoot 'unsafe-smoke-result.json'
        & $script:CurrentEngine -NoLogo -NoProfile -NonInteractive -File (Join-Path $script:RepositoryRoot 'tools\Test-DetectionSmoke.ps1') -RepositoryRoot $script:FixtureRoot -OutputRoot $output -Scope CustomCompliance -PackagePath 'Custom-Compliance/Security/Unsafe-Smoke' -SummaryOnly -ResultPath $resultPath
        $LASTEXITCODE | Should -Be 1
        $detail = [System.IO.File]::ReadAllText((Join-Path $output 'detection-smoke-results.json')) | ConvertFrom-Json
        ($detail.FailureReasons -join ' ') | Should -Match 'was not executed'
        $detail.StdOut | Should -BeNullOrEmpty
    }

    It 'fails a read-only script that exceeds the smoke timeout' -Skip:([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
        $package = Join-Path $script:FixtureRoot 'Detection-Remediation\Security\Slow-Detection'
        Write-TestFile (Join-Path $package 'ScriptInfo.json') (New-TestScriptInfo -Workload 'Detection and Remediation' -Status PilotReady -HasRemediation Yes)
        Write-TestFile (Join-Path $package 'Detect.ps1') "# =========================`n# MAIN`n# =========================`nStart-Sleep -Seconds 20`nexit 0"
        $output = Join-Path $script:FixtureRoot 'smoke-output'
        $resultPath = Join-Path $script:FixtureRoot 'smoke-structured.json'
        & $script:CurrentEngine -NoLogo -NoProfile -NonInteractive -File (Join-Path $script:RepositoryRoot 'tools\Test-DetectionSmoke.ps1') -RepositoryRoot $script:FixtureRoot -OutputRoot $output -Scope Remediation -PackagePath 'Detection-Remediation/Security/Slow-Detection' -TimeoutSeconds 5 -SummaryOnly -ResultPath $resultPath
        $LASTEXITCODE | Should -Be 1
        $detail = [System.IO.File]::ReadAllText((Join-Path $output 'detection-smoke-results.json')) | ConvertFrom-Json
        $detail.TimedOut | Should -BeTrue
    }
}

Describe 'Registry remediation audit' {
    It 'locks the tracked audit to all 100 current registry candidates' {
        $resultPath = Join-Path $script:FixtureRoot 'registry-audit-current-result.json'
        & $script:CurrentEngine -NoLogo -NoProfile -NonInteractive -File (Join-Path $script:RepositoryRoot 'tools\Test-RegistryRemediationAudit.ps1') -RepositoryRoot $script:RepositoryRoot -SummaryOnly -ResultPath $resultPath
        $result = [System.IO.File]::ReadAllText($resultPath) | ConvertFrom-Json
        $LASTEXITCODE | Should -Be 0 -Because ($result.Results.Message -join '; ')
        $result.CandidateCount | Should -Be 100
        $result.EntryCount | Should -Be 100
        $result.Counts.Failure | Should -Be 0
    }

    It 'blocks PilotReady registry scripts that do not verify the value type' {
        $relativePackage = 'Detection-Remediation/Security/Fixture-Registry-Type'
        $package = Join-Path $script:FixtureRoot ($relativePackage.Replace('/', '\'))
        $auditPath = Join-Path $script:FixtureRoot 'registry-audit-type-gate.json'
        $resultPath = Join-Path $script:FixtureRoot 'registry-audit-type-gate-result.json'
        try {
            Write-TestFile -Path (Join-Path $package 'ScriptInfo.json') -Content (New-TestScriptInfo -Workload 'Detection and Remediation' -Status PilotReady -HasRemediation Yes -EvidenceSource Registry)
            $scriptBody = @'
# CONFIGURATION
$RegistryValues = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Fixture'; Name = 'Enabled'; Type = 'DWord'; Value = 1 }
)
# LOGGING
# MAIN
$state = Get-ItemProperty -LiteralPath $RegistryValues[0].Path -ErrorAction SilentlyContinue
if ($state) { exit 0 }
exit 1
'@
            Write-TestFile -Path (Join-Path $package 'Detect.ps1') -Content $scriptBody
            Write-TestFile -Path (Join-Path $package 'Remediate.ps1') -Content $scriptBody
            Write-TestFile -Path $auditPath -Content (@{
                SchemaVersion = '1.0'
                ReviewedOn = '2026-08-18'
                CandidateDefinition = 'Fixture registry readers.'
                Packages = @(@{
                    Path = $relativePackage
                    Disposition = 'PilotReady'
                    Batch = 1
                    Reason = 'Fixture must validate type.'
                    MicrosoftReferences = @('https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations')
                })
            } | ConvertTo-Json -Depth 8)

            & $script:CurrentEngine -NoLogo -NoProfile -NonInteractive -File (Join-Path $script:RepositoryRoot 'tools\Test-RegistryRemediationAudit.ps1') -RepositoryRoot $script:FixtureRoot -AuditPath $auditPath -SummaryOnly -ResultPath $resultPath
            $LASTEXITCODE | Should -Be 1
            $result = [System.IO.File]::ReadAllText($resultPath) | ConvertFrom-Json
            @($result.Results.RuleId) | Should -Contain 'RegistryAudit.ValueType'
        }
        finally {
            if (Test-Path -LiteralPath $package) { Remove-Item -LiteralPath $package -Recurse -Force }
            foreach ($path in @($auditPath, $resultPath)) {
                if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
            }
        }
    }
}

Describe 'Defender remediation audit' {
    It 'locks every Defender cmdlet remediation to a source-reviewed PilotReady package' {
        $auditPath = Join-Path $script:RepositoryRoot 'validation\defender-remediation-audit.json'
        $audit = [System.IO.File]::ReadAllText($auditPath) | ConvertFrom-Json
        $candidateRoot = Join-Path $script:RepositoryRoot 'Detection-Remediation\Security'
        $candidatePaths = @(Get-ChildItem -LiteralPath $candidateRoot -Directory | Where-Object Name -Like 'Defender-*' | ForEach-Object {
                "Detection-Remediation/Security/$($_.Name)"
            } | Sort-Object -Unique)
        $auditPaths = @($audit.Packages.Path | Sort-Object -Unique)

        $candidatePaths.Count | Should -Be 11
        $auditPaths.Count | Should -Be 11
        (Compare-Object -ReferenceObject $candidatePaths -DifferenceObject $auditPaths) | Should -BeNullOrEmpty

        foreach ($entry in $audit.Packages) {
            $entry.Disposition | Should -Be 'PilotReady'
            @($entry.MicrosoftReferences).Count | Should -BeGreaterThan 1
            $package = Join-Path $script:RepositoryRoot ($entry.Path.Replace('/', '\'))
            $metadata = [System.IO.File]::ReadAllText((Join-Path $package 'ScriptInfo.json')) | ConvertFrom-Json
            $metadata.Status | Should -Be 'PilotReady'
            $metadata.Context | Should -Be 'System'
            $metadata.DetectionEvidenceType | Should -Be 'DirectEvidence'
            $metadata.DetectionReviewStatus | Should -Be 'Reviewed'
        }
    }
}

Describe 'Direct security and health remediation audit' {
    BeforeAll {
        $script:DirectAuditPath = Join-Path $script:RepositoryRoot 'validation\direct-security-health-remediation-audit.json'
        $script:DirectAudit = [System.IO.File]::ReadAllText($script:DirectAuditPath) | ConvertFrom-Json
    }

    It 'records all reviewed packages with an honest disposition' {
        $entries = @($script:DirectAudit.Packages)
        $paths = @($entries.Path | Sort-Object -Unique)

        $entries.Count | Should -Be 15
        $paths.Count | Should -Be 15
        @($entries | Where-Object Disposition -EQ 'PilotReady').Count | Should -Be 8
        @($entries | Where-Object Disposition -EQ 'RetainExample').Count | Should -Be 6
        @($entries | Where-Object Disposition -EQ 'NeedsReview').Count | Should -Be 1

        foreach ($entry in $entries) {
            @($entry.MicrosoftReferences).Count | Should -BeGreaterOrEqual 2
            $package = Join-Path $script:RepositoryRoot ($entry.Path.Replace('/', '\'))
            Test-Path -LiteralPath $package -PathType Container | Should -BeTrue
            $metadata = [System.IO.File]::ReadAllText((Join-Path $package 'ScriptInfo.json')) | ConvertFrom-Json

            switch ($entry.Disposition) {
                'PilotReady' { $metadata.Status | Should -Be 'PilotReady' }
                'RetainExample' { $metadata.Status | Should -Be 'Example' }
                'NeedsReview' { $metadata.Status | Should -Be 'NeedsReview' }
            }

            if ($entry.Disposition -eq 'PilotReady') {
                $metadata.Context | Should -Be 'System'
                $metadata.DetectionEvidenceType | Should -Be 'DirectEvidence'
                $metadata.DetectionReviewStatus | Should -Be 'Reviewed'
            }
        }
    }

    It 'prevents report-only service remediation from reporting false success' {
        $servicePackages = @(
            'Detection-Remediation/Security/Ensure-Base-Filtering-Engine-Service-Running',
            'Detection-Remediation/Security/Ensure-Security-Center-Service-Running',
            'Detection-Remediation/Endpoint-Health/Ensure-Windows-Event-Log-Service-Running',
            'Detection-Remediation/Maintenance/Ensure-Task-Scheduler-Service-Running',
            'Detection-Remediation/Windows-Updates/Ensure-Cryptographic-Service-Running'
        )

        foreach ($relativePath in $servicePackages) {
            $remediationPath = Join-Path $script:RepositoryRoot (($relativePath + '/Remediate.ps1').Replace('/', '\'))
            $content = [System.IO.File]::ReadAllText($remediationPath)
            $block = [regex]::Match($content, 'if \(-not \$StartService\) \{(?s:.*?)\r?\n\s*\}')

            $block.Success | Should -BeTrue -Because $relativePath
            $block.Value | Should -Match 'exit 1' -Because $relativePath
            $block.Value | Should -Not -Match 'exit 0' -Because $relativePath
        }
    }

    It 'keeps account and Defender report-only paths noncompliant' {
        $guest = [System.IO.File]::ReadAllText((Join-Path $script:RepositoryRoot 'Detection-Remediation\Security\Ensure-Guest-Account-Disabled\Remediate.ps1'))
        $signature = [System.IO.File]::ReadAllText((Join-Path $script:RepositoryRoot 'Detection-Remediation\Security\Update-Defender-Signatures\Remediate.ps1'))

        $guest | Should -Not -Match 'ExitZeroInReportingOnlyMode'
        $signature | Should -Not -Match 'ExitZeroInReportingOnlyMode'
        $signature | Should -Match 'ValidationAttempts'
        $signature | Should -Match 'allowedUpdateSources'
    }
}
