#Requires -Version 5.1

Set-StrictMode -Version 2.0

$script:WorkloadFolders = @(
    'Detection-Remediation',
    'Custom-Compliance',
    'Intune-Platform-Scripts',
    'Win32-Packaged-Scripts'
)

function ConvertTo-ValidationPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Path
    )

    return $Path.Replace('\', '/').TrimStart('./').TrimEnd('/')
}

function Get-ValidationRelativePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $baseUri = New-Object System.Uri(($BasePath.TrimEnd('\') + '\'))
    $pathUri = New-Object System.Uri($Path)
    return (ConvertTo-ValidationPath -Path ([System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString())))
}

function Get-ValidationPackagePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryPath
    )

    $normalized = ConvertTo-ValidationPath -Path $RepositoryPath
    $parts = @($normalized -split '/')
    if ($parts.Count -lt 3 -or $parts[0] -notin $script:WorkloadFolders) {
        return $null
    }

    return ($parts[0..2] -join '/')
}

function Get-ValidationPackageInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot
    )

    $packages = New-Object System.Collections.Generic.List[string]
    foreach ($workload in $script:WorkloadFolders) {
        $workloadPath = Join-Path -Path $RepositoryRoot -ChildPath $workload
        if (-not (Test-Path -LiteralPath $workloadPath -PathType Container)) {
            continue
        }

        foreach ($purpose in @(Get-ChildItem -LiteralPath $workloadPath -Directory | Sort-Object Name)) {
            foreach ($package in @(Get-ChildItem -LiteralPath $purpose.FullName -Directory | Sort-Object Name)) {
                $packages.Add((Get-ValidationRelativePath -BasePath $RepositoryRoot -Path $package.FullName))
            }
        }
    }

    return @($packages.ToArray() | Sort-Object -Unique)
}

function Test-ValidationPackageSelected {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$CandidatePath,
        [string[]]$PackagePath
    )

    $selected = @($PackagePath | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { ConvertTo-ValidationPath -Path $_ })
    if ($selected.Count -eq 0) {
        return $true
    }

    $candidate = ConvertTo-ValidationPath -Path $CandidatePath
    return $candidate -in $selected
}

function Test-ValidationGlobalChange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryPath
    )

    $path = ConvertTo-ValidationPath -Path $RepositoryPath
    $patterns = @(
        '^tools/Invoke-Validation\.ps1$',
        '^tools/IntuneLibrary\.Validation\.psm1$',
        '^tools/Test-(Repository|IntuneWorkloadContracts|DetectionEvidence|ScriptPortability|DetectionSmoke)\.ps1$',
        '^templates/',
        '^\.github/workflows/',
        '^docs/Intune-Workload-Contracts\.md$',
        '^validation/.*\.schema\.json$',
        '^tests/'
    )

    foreach ($pattern in $patterns) {
        if ($path -match $pattern) {
            return $true
        }
    }

    return $false
}

function Test-GitCommitAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RepositoryRoot,
        [Parameter(Mandatory = $true)][string]$Ref
    )

    if ([string]::IsNullOrWhiteSpace($Ref)) {
        return $false
    }

    & git -C $RepositoryRoot rev-parse --verify --quiet "$Ref^{commit}" 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function ConvertFrom-GitNameStatus {
    [CmdletBinding()]
    param(
        [string[]]$Lines
    )

    $changes = New-Object System.Collections.Generic.List[object]
    foreach ($line in @($Lines)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $parts = @($line -split "`t")
        $status = [string]$parts[0]
        if ($status -match '^R\d+$' -or $status -match '^C\d+$') {
            if ($parts.Count -lt 3) { continue }
            $changes.Add([pscustomobject]@{ Status = $status; Path = (ConvertTo-ValidationPath $parts[1]); Side = 'Source' })
            $changes.Add([pscustomobject]@{ Status = $status; Path = (ConvertTo-ValidationPath $parts[2]); Side = 'Destination' })
        }
        elseif ($parts.Count -ge 2) {
            $changes.Add([pscustomobject]@{ Status = $status; Path = (ConvertTo-ValidationPath $parts[1]); Side = 'Path' })
        }
    }

    return @($changes.ToArray())
}

function Resolve-ValidationScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Changed', 'Full')][string]$Scope,
        [Parameter(Mandatory = $true)][string]$RepositoryRoot,
        [string]$BaseRef,
        [string]$HeadRef = 'HEAD',
        [ValidateRange(1, 10000)][int]$PackageThreshold = 100,
        [string[]]$NameStatusLines
    )

    $requestedScope = $Scope
    $effectiveScope = $Scope
    $escalationReason = $null
    $changes = @()

    if ($Scope -eq 'Changed') {
        if ($PSBoundParameters.ContainsKey('NameStatusLines')) {
            $changes = @(ConvertFrom-GitNameStatus -Lines $NameStatusLines)
        }
        elseif (-not (Test-GitCommitAvailable -RepositoryRoot $RepositoryRoot -Ref $BaseRef)) {
            $effectiveScope = 'Full'
            $escalationReason = "Base ref '$BaseRef' is unavailable."
        }
        elseif (-not (Test-GitCommitAvailable -RepositoryRoot $RepositoryRoot -Ref $HeadRef)) {
            $effectiveScope = 'Full'
            $escalationReason = "Head ref '$HeadRef' is unavailable."
        }
        else {
            $diffOutput = @(& git -C $RepositoryRoot diff --name-status -M $BaseRef $HeadRef --)
            if ($LASTEXITCODE -ne 0) {
                $effectiveScope = 'Full'
                $escalationReason = 'git diff could not determine the changed files.'
            }
            else {
                $changes = @(ConvertFrom-GitNameStatus -Lines $diffOutput)
            }
        }
    }

    $changedPaths = @($changes | ForEach-Object { $_.Path } | Sort-Object -Unique)
    $changedPackages = @($changedPaths | ForEach-Object { Get-ValidationPackagePath -RepositoryPath $_ } | Where-Object { $_ } | Sort-Object -Unique)

    if ($effectiveScope -eq 'Changed') {
        $globalPaths = @($changedPaths | Where-Object { Test-ValidationGlobalChange -RepositoryPath $_ })
        if ($globalPaths.Count -gt 0) {
            $effectiveScope = 'Full'
            $escalationReason = "Shared validation input changed: $($globalPaths[0])"
        }
        elseif ($changedPackages.Count -gt $PackageThreshold) {
            $effectiveScope = 'Full'
            $escalationReason = "Changed package count $($changedPackages.Count) exceeds threshold $PackageThreshold."
        }
    }

    $inventory = @(Get-ValidationPackageInventory -RepositoryRoot $RepositoryRoot)
    $selected = if ($effectiveScope -eq 'Full') {
        $inventory
    }
    else {
        @($changedPackages | Where-Object { $_ -in $inventory })
    }

    [pscustomobject][ordered]@{
        RequestedScope = $requestedScope
        EffectiveScope = $effectiveScope
        BaseRef = $BaseRef
        HeadRef = $HeadRef
        EscalationReason = $escalationReason
        ChangedPaths = $changedPaths
        ChangedPackagePaths = $changedPackages
        PackagePaths = @($selected | Sort-Object -Unique)
        DeletedOrMissingPackagePaths = @($changedPackages | Where-Object { $_ -notin $inventory } | Sort-Object -Unique)
        PackageCount = @($selected).Count
    }
}

function New-ValidationRuleResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RuleId,
        [Parameter(Mandatory = $true)][ValidateSet('Pass', 'Warning', 'Failure')][string]$Severity,
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$PackagePath = '',
        [string]$File = ''
    )

    [pscustomobject][ordered]@{
        RuleId = $RuleId
        Severity = $Severity
        PackagePath = (ConvertTo-ValidationPath -Path $PackagePath)
        File = (ConvertTo-ValidationPath -Path $File)
        Message = $Message
    }
}

function Write-ValidationResultFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$InputObject
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }

    $json = $InputObject | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($Path, ($json + [Environment]::NewLine), (New-Object System.Text.UTF8Encoding($false)))
}

function Get-ConfigurationSectionBounds {
    param([Parameter(Mandatory = $true)][string]$Content)

    $lines = @($Content -split '\r?\n')
    $start = 0
    $end = $lines.Count + 1
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^#\s*CONFIGURATION\s*$') {
            $start = $index + 1
            continue
        }
        if ($start -gt 0 -and $lines[$index] -match '^#\s*(LOGGING|MAIN)\s*$') {
            $end = $index + 1
            break
        }
    }

    if ($start -eq 0) {
        throw 'The script has no recognizable CONFIGURATION section.'
    }

    return [pscustomobject]@{ StartLine = $start; EndLine = $end }
}

function ConvertFrom-LiteralAst {
    param([Parameter(Mandatory = $true)][System.Management.Automation.Language.Ast]$Ast)

    if ($Ast -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
        return $Ast.Value
    }
    if ($Ast -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
        if ($Ast.NestedExpressions.Count -gt 0) { throw 'Expandable strings containing expressions are computed values.' }
        return $Ast.Value
    }
    if ($Ast -is [System.Management.Automation.Language.ConstantExpressionAst]) {
        return $Ast.Value
    }
    if ($Ast -is [System.Management.Automation.Language.VariableExpressionAst]) {
        switch ($Ast.VariablePath.UserPath.ToLowerInvariant()) {
            'true' { return $true }
            'false' { return $false }
            'null' { return $null }
            default { throw 'Variable references are computed values.' }
        }
    }
    if ($Ast -is [System.Management.Automation.Language.ParenExpressionAst]) {
        return ConvertFrom-LiteralAst -Ast $Ast.Pipeline
    }
    if ($Ast -is [System.Management.Automation.Language.PipelineAst]) {
        if ($Ast.PipelineElements.Count -ne 1) { throw 'Pipelines are computed values.' }
        return ConvertFrom-LiteralAst -Ast $Ast.PipelineElements[0]
    }
    if ($Ast -is [System.Management.Automation.Language.CommandExpressionAst]) {
        return ConvertFrom-LiteralAst -Ast $Ast.Expression
    }
    if ($Ast -is [System.Management.Automation.Language.UnaryExpressionAst]) {
        $value = ConvertFrom-LiteralAst -Ast $Ast.Child
        if ($Ast.TokenKind -eq [System.Management.Automation.Language.TokenKind]::Minus -and $value -is [ValueType]) {
            return -$value
        }
        if ($Ast.TokenKind -eq [System.Management.Automation.Language.TokenKind]::Plus -and $value -is [ValueType]) {
            return $value
        }
        throw 'The unary expression is not a supported literal.'
    }
    if ($Ast -is [System.Management.Automation.Language.ArrayLiteralAst]) {
        return @($Ast.Elements | ForEach-Object { ConvertFrom-LiteralAst -Ast $_ })
    }
    if ($Ast -is [System.Management.Automation.Language.ArrayExpressionAst]) {
        $values = New-Object System.Collections.Generic.List[object]
        foreach ($statement in @($Ast.SubExpression.Statements)) {
            $value = ConvertFrom-LiteralAst -Ast $statement
            foreach ($item in @($value)) { $values.Add($item) }
        }
        return @($values.ToArray())
    }

    throw "AST node '$($Ast.GetType().Name)' is a computed or unsupported value."
}

function Get-ValidationConfigurationValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string]$Variable
    )

    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        throw "Script '$ScriptPath' does not exist."
    }

    $content = [System.IO.File]::ReadAllText($ScriptPath)
    $bounds = Get-ConfigurationSectionBounds -Content $content
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, $ScriptPath, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        throw "Script '$ScriptPath' has PowerShell parse errors: $($errors[0].Message)"
    }

    $assignments = @($ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $node.Left.VariablePath.UserPath -eq $Variable -and
                $node.Extent.StartLineNumber -gt $bounds.StartLine -and
                $node.Extent.StartLineNumber -lt $bounds.EndLine
            }, $true))

    if ($assignments.Count -eq 0) {
        throw "Configuration variable '$Variable' was not found in '$ScriptPath'."
    }
    if ($assignments.Count -gt 1) {
        throw "Configuration variable '$Variable' is assigned more than once in '$ScriptPath'."
    }

    try {
        return ConvertFrom-LiteralAst -Ast $assignments[0].Right
    }
    catch {
        throw "Configuration variable '$Variable' in '$ScriptPath' is not a supported literal. $($_.Exception.Message)"
    }
}

function Test-ValidationValueEqual {
    param([AllowNull()][object]$Actual, [AllowNull()][object]$Expected)

    if ($null -eq $Actual -or $null -eq $Expected) { return ($null -eq $Actual -and $null -eq $Expected) }
    $actualItems = @($Actual)
    $expectedItems = @($Expected)
    if ($actualItems.Count -ne $expectedItems.Count) { return $false }
    for ($index = 0; $index -lt $actualItems.Count; $index++) {
        if ($null -eq $actualItems[$index] -or $null -eq $expectedItems[$index]) {
            if (-not ($null -eq $actualItems[$index] -and $null -eq $expectedItems[$index])) { return $false }
        }
        elseif ($actualItems[$index].GetType().FullName -ne $expectedItems[$index].GetType().FullName -or $actualItems[$index] -ne $expectedItems[$index]) {
            return $false
        }
    }
    return $true
}

function Test-TenantValidationProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ProfilePath,
        [Parameter(Mandatory = $true)][string]$RepositoryRoot
    )

    $results = New-Object System.Collections.Generic.List[object]
    try {
        $profile = [System.IO.File]::ReadAllText($ProfilePath) | ConvertFrom-Json
    }
    catch {
        $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.ValidJson' -Severity Failure -Message "Tenant profile could not be parsed: $($_.Exception.Message)" -File $ProfilePath))
        return @($results.ToArray())
    }

    $allowedRoot = @('$schema', 'SchemaVersion', 'Packages')
    foreach ($property in @($profile.PSObject.Properties.Name)) {
        if ($property -notin $allowedRoot) {
            $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.UnknownProperty' -Severity Failure -Message "Unknown tenant profile property '$property'." -File $ProfilePath))
        }
    }
    if (-not $profile.PSObject.Properties.Name.Contains('SchemaVersion') -or [string]$profile.SchemaVersion -ne '1.0') {
        $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.SchemaVersion' -Severity Failure -Message "Tenant profile SchemaVersion must be '1.0'." -File $ProfilePath))
    }
    if (-not $profile.PSObject.Properties.Name.Contains('Packages')) {
        $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.PackagesRequired' -Severity Failure -Message 'Tenant profile must contain Packages.' -File $ProfilePath))
        return @($results.ToArray())
    }

    $seen = @{}
    $repositoryPackages = @(Get-ValidationPackageInventory -RepositoryRoot $RepositoryRoot)
    foreach ($entry in @($profile.Packages)) {
        $entryProperties = @($entry.PSObject.Properties.Name)
        $allowedEntry = @('Path', 'AllowedStatuses', 'ExpectedContext', 'ConfigurationAssertions')
        foreach ($property in $entryProperties) {
            if ($property -notin $allowedEntry) {
                $unknownPath = if ($entryProperties -contains 'Path') { [string]$entry.Path } else { '' }
                $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.UnknownPackageProperty' -Severity Failure -Message "Unknown package property '$property'." -PackagePath $unknownPath))
            }
        }

        $packagePath = if ($entryProperties -contains 'Path') { ConvertTo-ValidationPath -Path ([string]$entry.Path) } else { '' }
        if ([string]::IsNullOrWhiteSpace($packagePath)) {
            $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.PathRequired' -Severity Failure -Message 'A tenant profile package is missing Path.'))
            continue
        }
        $key = $packagePath.ToLowerInvariant()
        if ($seen.ContainsKey($key)) {
            $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.DuplicatePath' -Severity Failure -Message "Duplicate package path '$packagePath'." -PackagePath $packagePath))
            continue
        }
        $seen[$key] = $true

        if ($packagePath -notin $repositoryPackages) {
            $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.PackageExists' -Severity Failure -Message "Package '$packagePath' does not exist." -PackagePath $packagePath))
            continue
        }
        $absolutePackage = Join-Path -Path $RepositoryRoot -ChildPath ($packagePath.Replace('/', '\'))

        $scriptInfoPath = Join-Path -Path $absolutePackage -ChildPath 'ScriptInfo.json'
        try { $scriptInfo = [System.IO.File]::ReadAllText($scriptInfoPath) | ConvertFrom-Json }
        catch {
            $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.ScriptInfo' -Severity Failure -Message "ScriptInfo.json could not be read: $($_.Exception.Message)" -PackagePath $packagePath -File $scriptInfoPath))
            continue
        }

        $allowedStatuses = @()
        if ($entryProperties -contains 'AllowedStatuses') {
            $allowedStatuses = @($entry.AllowedStatuses)
        }
        if ($allowedStatuses.Count -eq 0) {
            $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.AllowedStatusesRequired' -Severity Failure -Message 'AllowedStatuses must contain at least one status.' -PackagePath $packagePath))
        }
        foreach ($status in $allowedStatuses) {
            if ($status -notin @('Template', 'Planned', 'Example', 'NeedsReview', 'PilotReady', 'Validated')) {
                $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.ValidAllowedStatus' -Severity Failure -Message "Allowed status '$status' is invalid." -PackagePath $packagePath))
            }
        }
        if ([string]$scriptInfo.Status -notin $allowedStatuses) {
            $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.Status' -Severity Failure -Message "Package status '$($scriptInfo.Status)' is not one of: $($allowedStatuses -join ', ')." -PackagePath $packagePath))
        }
        $expectedContext = if ($entryProperties -contains 'ExpectedContext') { [string]$entry.ExpectedContext } else { '' }
        if ([string]::IsNullOrWhiteSpace($expectedContext)) {
            $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.ExpectedContextRequired' -Severity Failure -Message 'ExpectedContext is required.' -PackagePath $packagePath))
        }
        elseif ([string]$scriptInfo.Context -ne $expectedContext) {
            $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.Context' -Severity Failure -Message "Package context '$($scriptInfo.Context)' does not match expected '$expectedContext'." -PackagePath $packagePath))
        }

        $assertions = if ($entry.PSObject.Properties.Name.Contains('ConfigurationAssertions')) { @($entry.ConfigurationAssertions) } else { @() }
        foreach ($assertion in $assertions) {
            $assertionProperties = @($assertion.PSObject.Properties.Name)
            $allowedAssertion = @('Script', 'Variable', 'Equals')
            foreach ($property in $assertionProperties) {
                if ($property -notin $allowedAssertion) {
                    $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.UnknownAssertionProperty' -Severity Failure -Message "Unknown assertion property '$property'." -PackagePath $packagePath))
                }
            }
            $missingAssertionProperties = @($allowedAssertion | Where-Object { $_ -notin $assertionProperties })
            if ($missingAssertionProperties.Count -gt 0) {
                $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.AssertionPropertiesRequired' -Severity Failure -Message "Configuration assertion is missing: $($missingAssertionProperties -join ', ')." -PackagePath $packagePath))
                continue
            }
            $assertionScriptName = [string]$assertion.Script
            if ([System.IO.Path]::IsPathRooted($assertionScriptName) -or [System.IO.Path]::GetFileName($assertionScriptName) -ne $assertionScriptName -or [System.IO.Path]::GetExtension($assertionScriptName) -ne '.ps1') {
                $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.AssertionScriptPath' -Severity Failure -Message "Assertion Script '$assertionScriptName' must name a .ps1 file directly inside the package." -PackagePath $packagePath -File $assertionScriptName))
                continue
            }
            $assertionScript = Join-Path -Path $absolutePackage -ChildPath $assertionScriptName
            try {
                $actual = Get-ValidationConfigurationValue -ScriptPath $assertionScript -Variable ([string]$assertion.Variable)
                if (-not (Test-ValidationValueEqual -Actual $actual -Expected $assertion.Equals)) {
                    $actualJson = $actual | ConvertTo-Json -Compress -Depth 5
                    $expectedJson = $assertion.Equals | ConvertTo-Json -Compress -Depth 5
                    $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.ConfigurationAssertion' -Severity Failure -Message "Variable '$($assertion.Variable)' is $actualJson; expected $expectedJson." -PackagePath $packagePath -File ([string]$assertion.Script)))
                }
            }
            catch {
                $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.ConfigurationAssertion' -Severity Failure -Message $_.Exception.Message -PackagePath $packagePath -File ([string]$assertion.Script)))
            }
        }
    }

    if ($results.Count -eq 0) {
        $results.Add((New-ValidationRuleResult -RuleId 'TenantProfile.Valid' -Severity Pass -Message "Tenant profile contains $(@($profile.Packages).Count) valid package entries." -File $ProfilePath))
    }
    return @($results.ToArray())
}

function Test-CustomComplianceOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$StdOut,
        [Parameter(Mandatory = $true)][string]$RulesPath,
        [string]$PackagePath = ''
    )

    $results = New-Object System.Collections.Generic.List[object]
    $lines = @($StdOut -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($lines.Count -ne 1) {
        $results.Add((New-ValidationRuleResult -RuleId 'Smoke.CustomCompliance.SingleJsonObject' -Severity Failure -Message "Discover.ps1 emitted $($lines.Count) non-empty output lines; exactly one JSON object is required." -PackagePath $PackagePath))
        return @($results.ToArray())
    }
    try { $outputObject = $lines[0] | ConvertFrom-Json }
    catch {
        $results.Add((New-ValidationRuleResult -RuleId 'Smoke.CustomCompliance.ValidJson' -Severity Failure -Message "Discovery output is not valid JSON: $($_.Exception.Message)" -PackagePath $PackagePath))
        return @($results.ToArray())
    }
    if ($outputObject -is [System.Array] -or $outputObject -isnot [pscustomobject]) {
        $results.Add((New-ValidationRuleResult -RuleId 'Smoke.CustomCompliance.JsonObject' -Severity Failure -Message 'Discovery output must be one JSON object, not an array or scalar.' -PackagePath $PackagePath))
        return @($results.ToArray())
    }
    try { $ruleDocument = [System.IO.File]::ReadAllText($RulesPath) | ConvertFrom-Json }
    catch {
        $results.Add((New-ValidationRuleResult -RuleId 'Smoke.CustomCompliance.RulesJson' -Severity Failure -Message "Compliance rules could not be parsed: $($_.Exception.Message)" -PackagePath $PackagePath -File $RulesPath))
        return @($results.ToArray())
    }

    $ruleDocumentProperties = @($ruleDocument.PSObject.Properties | ForEach-Object { $_.Name })
    if ($ruleDocumentProperties -notcontains 'Rules' -or @($ruleDocument.Rules).Count -eq 0) {
        $results.Add((New-ValidationRuleResult -RuleId 'Smoke.CustomCompliance.RulesRequired' -Severity Failure -Message 'ComplianceRules.json must contain at least one rule.' -PackagePath $PackagePath -File $RulesPath))
        return @($results.ToArray())
    }

    foreach ($rule in @($ruleDocument.Rules)) {
        $name = [string]$rule.SettingName
        $property = $outputObject.PSObject.Properties[$name]
        if ($null -eq $property) {
            $results.Add((New-ValidationRuleResult -RuleId 'Smoke.CustomCompliance.RuleKey' -Severity Failure -Message "Discovery output is missing rule key '$name'." -PackagePath $PackagePath))
            continue
        }
        $value = $property.Value
        $typeMatches = switch ([string]$rule.DataType) {
            'Boolean' { $value -is [bool] }
            'Int64' { $value -is [sbyte] -or $value -is [byte] -or $value -is [int16] -or $value -is [uint16] -or $value -is [int32] -or $value -is [uint32] -or $value -is [int64] -or $value -is [uint64] }
            'Double' { $value -is [double] -or $value -is [single] -or $value -is [decimal] -or $value -is [int] -or $value -is [long] }
            'String' { $value -is [string] }
            'DateTime' { $parsed = [datetime]::MinValue; [datetime]::TryParse([string]$value, [ref]$parsed) }
            'Version' { $parsedVersion = $null; [version]::TryParse([string]$value, [ref]$parsedVersion) }
            default { $false }
        }
        if (-not $typeMatches) {
            $typeName = if ($null -eq $value) { 'null' } else { $value.GetType().Name }
            $results.Add((New-ValidationRuleResult -RuleId 'Smoke.CustomCompliance.RuleType' -Severity Failure -Message "Rule key '$name' has type '$typeName'; expected '$($rule.DataType)'." -PackagePath $PackagePath))
        }
    }
    if ($results.Count -eq 0) {
        $results.Add((New-ValidationRuleResult -RuleId 'Smoke.CustomCompliance.OutputContract' -Severity Pass -Message 'Discovery output matches all Custom Compliance rule keys and types.' -PackagePath $PackagePath))
    }
    return @($results.ToArray())
}

function Write-ValidationSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Report,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Validation Summary')
    $lines.Add('')
    $lines.Add("- Requested scope: $($Report.Scope.Requested)")
    $lines.Add("- Effective scope: $($Report.Scope.Effective)")
    $lines.Add("- Packages: $($Report.Counts.Packages)")
    $lines.Add("- Passed checks: $($Report.Counts.Pass)")
    $lines.Add("- Warnings: $($Report.Counts.Warning)")
    $lines.Add("- Failures: $($Report.Counts.Failure)")
    if (-not [string]::IsNullOrWhiteSpace([string]$Report.Scope.EscalationReason)) {
        $lines.Add("- Escalation: $($Report.Scope.EscalationReason)")
    }
    $lines.Add('')
    $lines.Add('## Top warnings and failures')
    $lines.Add('')
    $top = @($Report.Results | Where-Object { $_.Severity -in @('Failure', 'Warning') } | Sort-Object @{ Expression = { if ($_.Severity -eq 'Failure') { 0 } else { 1 } } }, RuleId, PackagePath, Message | Select-Object -First 20)
    if ($top.Count -eq 0) {
        $lines.Add('No warnings or failures.')
    }
    else {
        foreach ($item in $top) {
            $location = if ([string]::IsNullOrWhiteSpace([string]$item.PackagePath)) { '' } else { " [$($item.PackagePath)]" }
            $lines.Add("- **$($item.Severity)** ``$($item.RuleId)``$location — $($item.Message)")
        }
    }

    [System.IO.File]::WriteAllText($Path, (($lines -join [Environment]::NewLine) + [Environment]::NewLine), (New-Object System.Text.UTF8Encoding($false)))
}

Export-ModuleMember -Function @(
    'ConvertTo-ValidationPath',
    'Get-ValidationRelativePath',
    'Get-ValidationPackagePath',
    'Get-ValidationPackageInventory',
    'Test-ValidationPackageSelected',
    'Test-ValidationGlobalChange',
    'ConvertFrom-GitNameStatus',
    'Resolve-ValidationScope',
    'New-ValidationRuleResult',
    'Write-ValidationResultFile',
    'Get-ValidationConfigurationValue',
    'Test-TenantValidationProfile',
    'Test-CustomComplianceOutput',
    'Write-ValidationSummary'
)
