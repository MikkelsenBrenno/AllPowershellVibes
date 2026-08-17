<#
.SYNOPSIS
    Opens a standalone GUI for finding and customizing Intune remediation packages.

.DESCRIPTION
    Windows PowerShell 5.1 WinForms app for browsing a local Intune script
    library clone, editing variables from Detection and Remediation package
    CONFIGURATION blocks, previewing the final files, and exporting a complete
    customized package folder.

.NOTES
    Name:        Start-IntuneScriptLibraryGui.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     Local technician
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$RepositoryRoot = '',

    [switch]$IndexOnly,

    [string]$ExportPackage = '',

    [string]$ExportName = '',

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$script:AppRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$script:GeneratedRoot = Join-Path -Path $script:AppRoot -ChildPath 'Generated-Packages'
$script:SettingsPath = Join-Path -Path $script:AppRoot -ChildPath 'IntuneScriptLibraryGui.settings.json'

$script:Packages = @()
$script:FilteredPackages = @()
$script:SelectedPackage = $null
$script:ConfigItems = @()
$script:ConfigGroups = @()
$script:SelectedConfigGroup = $null
$script:LoadingSettingEditor = $false
$script:PreviewDetectText = ''
$script:PreviewRemediateText = ''
$script:LastExportPath = ''
$script:ActiveRepositoryRoot = ''

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

function ConvertTo-WindowsTextBoxText {
    param(
        [AllowNull()]
        [string]$Text
    )

    if ($null -eq $Text) {
        return ''
    }

    return [regex]::Replace($Text, '\r\n|\n|\r', [System.Environment]::NewLine)
}

function Write-TextFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $encoding)
}

function Get-GuiSettings {
    if (-not (Test-Path -LiteralPath $script:SettingsPath -PathType Leaf)) {
        return [pscustomobject]@{}
    }

    try {
        return Get-Content -LiteralPath $script:SettingsPath -Raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{}
    }
}

function Save-GuiSettings {
    param(
        [string]$RepositoryRoot
    )

    try {
        $settings = [ordered]@{
            RepositoryRoot = $RepositoryRoot
            UpdatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }

        if (-not (Test-Path -LiteralPath $script:AppRoot -PathType Container)) {
            New-Item -Path $script:AppRoot -ItemType Directory -Force | Out-Null
        }

        $settings | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8
    }
    catch {
        # Settings are a convenience only. Do not block the tool if they fail.
    }
}

function Resolve-FullPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return (Resolve-Path -LiteralPath $Path).Path
}

function Test-ScriptLibraryRoot {
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $detectionRoot = Join-Path -Path $Path -ChildPath 'Detection-Remediation'
    return (Test-Path -LiteralPath $detectionRoot -PathType Container)
}

function Get-DefaultRepositoryRoot {
    if (-not [string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        try {
            $resolved = Resolve-FullPath -Path $RepositoryRoot
            if (Test-ScriptLibraryRoot -Path $resolved) {
                return $resolved
            }
        }
        catch {}
    }

    $settings = Get-GuiSettings
    if ($settings.PSObject.Properties.Name -contains 'RepositoryRoot') {
        try {
            $resolved = Resolve-FullPath -Path ([string]$settings.RepositoryRoot)
            if (Test-ScriptLibraryRoot -Path $resolved) {
                return $resolved
            }
        }
        catch {}
    }

    $parent = Split-Path -Parent $script:AppRoot
    if (Test-ScriptLibraryRoot -Path $parent) {
        return (Resolve-FullPath -Path $parent)
    }

    if (Test-ScriptLibraryRoot -Path (Get-Location).Path) {
        return (Resolve-FullPath -Path (Get-Location).Path)
    }

    return ''
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root)
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    if (-not $rootFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $rootFull += [System.IO.Path]::DirectorySeparatorChar
    }

    $rootUri = New-Object System.Uri($rootFull)
    $pathUri = New-Object System.Uri($pathFull)
    return [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString()).Replace('/', '\')
}

function Get-SafeText {
    param(
        [object]$Value,
        [string]$Default = ''
    )

    if ($null -eq $Value) {
        return $Default
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $Default
    }

    return $text
}

function Read-ScriptInfo {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Get-RemediationPackageIndex {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot
    )

    $resolvedRoot = Resolve-FullPath -Path $RepositoryRoot
    if (-not (Test-ScriptLibraryRoot -Path $resolvedRoot)) {
        throw "Repository root '$resolvedRoot' does not contain a Detection-Remediation folder."
    }

    $remediationRoot = Join-Path -Path $resolvedRoot -ChildPath 'Detection-Remediation'
    $packages = New-Object System.Collections.Generic.List[object]

    Get-ChildItem -LiteralPath $remediationRoot -Directory | Sort-Object Name | ForEach-Object {
        $categoryFolder = $_

        Get-ChildItem -LiteralPath $categoryFolder.FullName -Directory | Sort-Object Name | ForEach-Object {
            $packageFolder = $_
            $detectPath = Join-Path -Path $packageFolder.FullName -ChildPath 'Detect.ps1'
            $remediatePath = Join-Path -Path $packageFolder.FullName -ChildPath 'Remediate.ps1'

            if (-not (Test-Path -LiteralPath $detectPath -PathType Leaf)) {
                return
            }

            if (-not (Test-Path -LiteralPath $remediatePath -PathType Leaf)) {
                return
            }

            $scriptInfoPath = Join-Path -Path $packageFolder.FullName -ChildPath 'ScriptInfo.json'
            $readmePath = Join-Path -Path $packageFolder.FullName -ChildPath 'README.md'
            $scriptInfo = Read-ScriptInfo -Path $scriptInfoPath

            $name = if ($scriptInfo) { Get-SafeText -Value $scriptInfo.Name -Default ($packageFolder.Name -replace '-', ' ') } else { $packageFolder.Name -replace '-', ' ' }
            $purpose = if ($scriptInfo) { Get-SafeText -Value $scriptInfo.Purpose -Default $categoryFolder.Name } else { $categoryFolder.Name }
            $risk = if ($scriptInfo) { Get-SafeText -Value $scriptInfo.Risk -Default 'Unknown' } else { 'Unknown' }
            $context = if ($scriptInfo) { Get-SafeText -Value $scriptInfo.Context -Default 'Unknown' } else { 'Unknown' }
            $summary = if ($scriptInfo) { Get-SafeText -Value $scriptInfo.Summary -Default '' } else { '' }
            $status = if ($scriptInfo) { Get-SafeText -Value $scriptInfo.Status -Default 'Unknown' } else { 'Unknown' }
            $relativePath = Get-RelativePath -Root $resolvedRoot -Path $packageFolder.FullName

            $searchText = @(
                $name
                $packageFolder.Name
                $purpose
                $risk
                $context
                $status
                $summary
                $relativePath
            ) -join ' '

            $packages.Add([pscustomobject]@{
                Name = $name
                FolderName = $packageFolder.Name
                Purpose = $purpose
                Risk = $risk
                Context = $context
                Status = $status
                Summary = $summary
                RelativePath = $relativePath
                FullPath = $packageFolder.FullName
                DetectPath = $detectPath
                RemediatePath = $remediatePath
                ReadmePath = $readmePath
                ScriptInfoPath = $scriptInfoPath
                SearchText = $searchText.ToLowerInvariant()
            })
        }
    }

    return @($packages.ToArray())
}

function Get-ConfigurationRange {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $pattern = '(?ms)^# =========================\r?\n# CONFIGURATION\r?\n# =========================\r?\n(?<Body>.*?)(?=^# =========================\r?\n# [^\r\n]+\r?\n# =========================)'
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) {
        return $null
    }

    return [pscustomobject]@{
        StartOffset = $match.Groups['Body'].Index
        EndOffset = $match.Groups['Body'].Index + $match.Groups['Body'].Length
    }
}

function Get-ValueKind {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Language.Ast]$RightAst,

        [Parameter(Mandatory = $true)]
        [string]$Expression
    )

    if ($Expression -match '^\s*\$(true|false)\s*$') {
        return 'Boolean'
    }

    if ($Expression -match '^\s*[-+]?\d+(\.\d+)?\s*$') {
        return 'Number'
    }

    if ($Expression -match '^\s*@\s*\(') {
        return 'Array'
    }

    if ($RightAst -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
        return 'String'
    }

    return 'Expression'
}

function Get-SimpleStringArrayValues {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Expression
    )

    $trimmed = $Expression.Trim()
    if ($trimmed -notmatch '^\s*@\s*\(' -or $trimmed -notmatch '\)\s*$') {
        return $null
    }

    $withoutQuotedStrings = [regex]::Replace($trimmed, "'(?:[^']|'')*'", "''")
    if ($withoutQuotedStrings -match '[^\s@(),''"]') {
        return $null
    }

    $values = New-Object System.Collections.Generic.List[string]
    foreach ($match in [regex]::Matches($trimmed, "'(?<Value>(?:[^']|'')*)'")) {
        $values.Add(($match.Groups['Value'].Value -replace "''", "'"))
    }

    return @($values.ToArray())
}

function Convert-JoinPathExpressionToFriendlyPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Expression
    )

    $pattern = "^\s*Join-Path\s+-Path\s+\`$env:(?<Env>[A-Za-z_][A-Za-z0-9_]*)\s+-ChildPath\s+'(?<Child>(?:[^']|'')*)'\s*$"
    $match = [regex]::Match($Expression, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) {
        return $null
    }

    $child = $match.Groups['Child'].Value -replace "''", "'"
    return ('$env:' + $match.Groups['Env'].Value + '\' + $child)
}

function Convert-FriendlyPathToExpression {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $trimmed = $Value.Trim()
    $envPattern = '^\$env:(?<Env>[A-Za-z_][A-Za-z0-9_]*)(\\(?<Child>.*))?$'
    $percentPattern = '^%(?<Env>[A-Za-z_][A-Za-z0-9_]*)%(\\(?<Child>.*))?$'

    $match = [regex]::Match($trimmed, $envPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) {
        $match = [regex]::Match($trimmed, $percentPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }

    if ($match.Success -and -not [string]::IsNullOrWhiteSpace($match.Groups['Child'].Value)) {
        $child = $match.Groups['Child'].Value -replace "'", "''"
        return "Join-Path -Path `$env:$($match.Groups['Env'].Value) -ChildPath '$child'"
    }

    return "'" + ($trimmed -replace "'", "''") + "'"
}

function Get-EditorKind {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Kind,

        [Parameter(Mandatory = $true)]
        [string]$Expression
    )

    if ($Kind -eq 'Boolean') {
        return 'Boolean'
    }

    if ($Kind -eq 'Number') {
        return 'Number'
    }

    if ($Kind -eq 'Array') {
        $arrayValues = Get-SimpleStringArrayValues -Expression $Expression
        if ($null -ne $arrayValues) {
            return 'StringList'
        }

        return 'Expression'
    }

    if ($Name -match '(Path|Root|Folder|Directory|File)' -and ($Kind -eq 'String' -or $null -ne (Convert-JoinPathExpressionToFriendlyPath -Expression $Expression))) {
        return 'Path'
    }

    if ($Kind -eq 'String') {
        return 'Text'
    }

    return 'Expression'
}

function Convert-ExpressionToEditorValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Kind,

        [Parameter(Mandatory = $true)]
        [string]$EditorKind,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Language.Ast]$RightAst,

        [Parameter(Mandatory = $true)]
        [string]$Expression
    )

    if ($EditorKind -eq 'StringList') {
        $arrayValues = Get-SimpleStringArrayValues -Expression $Expression
        if ($null -ne $arrayValues) {
            return ($arrayValues -join [System.Environment]::NewLine)
        }
    }

    if ($EditorKind -eq 'Path') {
        $friendlyPath = Convert-JoinPathExpressionToFriendlyPath -Expression $Expression
        if ($null -ne $friendlyPath) {
            return $friendlyPath
        }
    }

    switch ($Kind) {
        'String' {
            try {
                return [string]$RightAst.Value
            }
            catch {
                return $Expression
            }
        }
        'Boolean' {
            if ($Expression -match 'true') { return 'true' }
            return 'false'
        }
        default {
            return $Expression.Trim()
        }
    }
}

function Convert-EditorValueToExpression {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Item
    )

    $value = if ($null -eq $Item.EditorValue) { '' } else { [string]$Item.EditorValue }

    switch ($Item.EditorKind) {
        'Boolean' {
            $trimmed = $value.Trim()
            if ($trimmed -match '^(?i:\$?true|yes|1|enabled|on)$') { return '$true' }
            if ($trimmed -match '^(?i:\$?false|no|0|disabled|off)$') { return '$false' }
            throw "Boolean setting '$($Item.Name)' must be true or false."
        }
        'Number' {
            $trimmed = $value.Trim()
            if ($trimmed -notmatch '^[-+]?\d+(\.\d+)?$') {
                throw "Number setting '$($Item.Name)' must be numeric."
            }

            return $trimmed
        }
        'StringList' {
            $values = @(
                (ConvertTo-WindowsTextBoxText -Text $value).Split([string[]]@([System.Environment]::NewLine), [System.StringSplitOptions]::None) |
                    ForEach-Object { $_.Trim() } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            )

            if ($values.Count -eq 0) {
                return '@()'
            }

            $quoted = $values | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }
            return '@(' + ($quoted -join ', ') + ')'
        }
        'Path' {
            return Convert-FriendlyPathToExpression -Value $value
        }
        'Text' {
            return "'" + ($value -replace "'", "''") + "'"
        }
    }

    switch ($Item.Kind) {
        'String' {
            return "'" + ($value -replace "'", "''") + "'"
        }
        'Boolean' {
            $trimmed = $value.Trim()
            if ($trimmed -match '^(?i:\$?true|yes|1)$') { return '$true' }
            if ($trimmed -match '^(?i:\$?false|no|0)$') { return '$false' }
            return $trimmed
        }
        default {
            return $value.Trim()
        }
    }
}

function Get-ConfigurationEntries {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    $text = Read-TextFile -Path $ScriptPath
    $range = Get-ConfigurationRange -Text $text
    if ($null -eq $range) {
        return @()
    }

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$parseErrors)

    $assignments = $ast.FindAll({
        param($node)
        return (
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $node.Extent.StartOffset -ge $range.StartOffset -and
            $node.Extent.EndOffset -le $range.EndOffset
        )
    }, $true)

    $entries = New-Object System.Collections.Generic.List[object]
    foreach ($assignment in ($assignments | Sort-Object { $_.Extent.StartOffset })) {
        $name = $assignment.Left.VariablePath.UserPath
        $expression = $assignment.Right.Extent.Text.Trim()
        $kind = Get-ValueKind -RightAst $assignment.Right -Expression $expression
        $editorKind = Get-EditorKind -Name $name -Kind $kind -Expression $expression
        $editorValue = Convert-ExpressionToEditorValue -Kind $kind -EditorKind $editorKind -RightAst $assignment.Right -Expression $expression
        $friendlyName = Convert-VariableNameToFriendlyText -Name $name
        $isAdvanced = Test-ConfigurationItemAdvanced -Name $name
        $helpText = Get-ConfigurationHelpText -Name $name -Kind $kind -EditorKind $editorKind -Expression $expression
        $statementText = $assignment.Extent.Text

        $indent = ''
        if ($statementText -match '^(?<Indent>\s*)') {
            $indent = $Matches.Indent
        }

        $entries.Add([pscustomobject]@{
            FileName = $FileName
            Name = $name
            FriendlyName = $friendlyName
            Kind = $kind
            EditorKind = $editorKind
            OriginalExpression = $expression
            EditorValue = $editorValue
            OriginalEditorValue = $editorValue
            HelpText = $helpText
            IsAdvanced = $isAdvanced
            StartOffset = $assignment.Extent.StartOffset
            EndOffset = $assignment.Extent.EndOffset
            Indent = $indent
            OriginalStatement = $statementText
            ScriptPath = $ScriptPath
        })
    }

    return @($entries.ToArray())
}

function Get-PackageConfigItems {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Package
    )

    $items = @()
    $items += Get-ConfigurationEntries -ScriptPath $Package.DetectPath -FileName 'Detect.ps1'
    $items += Get-ConfigurationEntries -ScriptPath $Package.RemediatePath -FileName 'Remediate.ps1'
    return @($items)
}

function Get-ConfigurationAppliesToText {
    param(
        [object[]]$Items
    )

    $files = @($Items | Select-Object -ExpandProperty FileName -Unique)
    if ($files.Count -eq 2 -and $files -contains 'Detect.ps1' -and $files -contains 'Remediate.ps1') {
        return 'Both scripts'
    }

    return ($files -join ', ')
}

function Get-DisplayValueText {
    param(
        [AllowNull()]
        [string]$Value,

        [string]$EditorKind = ''
    )

    if ($null -eq $Value) {
        return ''
    }

    if ($EditorKind -eq 'StringList') {
        $items = @(
            (ConvertTo-WindowsTextBoxText -Text $Value).Split([string[]]@([System.Environment]::NewLine), [System.StringSplitOptions]::None) |
                ForEach-Object { $_.Trim() } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )

        if ($items.Count -eq 0) {
            return '(empty list)'
        }

        return ($items -join '; ')
    }

    return (ConvertTo-SingleLinePreview -Text $Value -MaximumLength 130)
}

function Get-ConfigurationGroups {
    param(
        [object[]]$Items
    )

    $groups = New-Object System.Collections.Generic.List[object]
    $byKey = [ordered]@{}

    foreach ($item in $Items) {
        $key = @(
            $item.Name
            $item.Kind
            $item.EditorKind
            [string]$item.EditorValue
            [string]$item.HelpText
            [string]$item.IsAdvanced
        ) -join '|'

        if (-not $byKey.Contains($key)) {
            $byKey[$key] = New-Object System.Collections.Generic.List[object]
        }

        $byKey[$key].Add($item)
    }

    foreach ($key in $byKey.Keys) {
        $groupItems = @($byKey[$key].ToArray())
        $first = $groupItems[0]
        $displayValue = Get-DisplayValueText -Value ([string]$first.EditorValue) -EditorKind $first.EditorKind

        $groups.Add([pscustomobject]@{
            FriendlyName = $first.FriendlyName
            Name = $first.Name
            Kind = $first.Kind
            EditorKind = $first.EditorKind
            EditorValue = $first.EditorValue
            OriginalEditorValue = $first.OriginalEditorValue
            HelpText = $first.HelpText
            IsAdvanced = $first.IsAdvanced
            Items = $groupItems
            AppliesTo = Get-ConfigurationAppliesToText -Items $groupItems
            DisplayValue = $displayValue
            TechnicalName = ('$' + $first.Name)
        })
    }

    return @($groups.ToArray())
}

function Set-ConfigurationGroupValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Group,

        [AllowNull()]
        [string]$Value
    )

    $Group.EditorValue = $Value
    $Group.DisplayValue = Get-DisplayValueText -Value $Value -EditorKind $Group.EditorKind

    foreach ($item in $Group.Items) {
        $item.EditorValue = $Value
    }
}

function Get-MarkdownSection {
    param(
        [string]$Text,

        [string]$Heading
    )

    if ([string]::IsNullOrWhiteSpace($Text) -or [string]::IsNullOrWhiteSpace($Heading)) {
        return ''
    }

    $normalized = ConvertTo-WindowsTextBoxText -Text $Text
    $escapedHeading = [regex]::Escape($Heading)
    $pattern = "(?ms)^##\s+$escapedHeading\s*\r?\n(?<Body>.*?)(?=^##\s+|\z)"
    $match = [regex]::Match($normalized, $pattern)

    if (-not $match.Success) {
        return ''
    }

    return $match.Groups['Body'].Value.Trim()
}

function ConvertTo-SingleLinePreview {
    param(
        [AllowNull()]
        [string]$Text,

        [int]$MaximumLength = 170
    )

    if ($null -eq $Text) {
        return ''
    }

    $singleLine = ([regex]::Replace($Text, '\s+', ' ')).Trim()
    if ($singleLine.Length -le $MaximumLength) {
        return $singleLine
    }

    return $singleLine.Substring(0, $MaximumLength - 3) + '...'
}

function Convert-VariableNameToFriendlyText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $spaced = $Name -creplace '([a-z0-9])([A-Z])', '$1 $2'
    $spaced = $spaced -creplace '([A-Z]+)([A-Z][a-z])', '$1 $2'
    $spaced = $spaced -replace '_', ' '
    $textInfo = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo
    $friendly = $textInfo.ToTitleCase($spaced.ToLowerInvariant())

    $friendly = $friendly -replace '\bUrl\b', 'URL'
    $friendly = $friendly -replace '\bUri\b', 'URI'
    $friendly = $friendly -replace '\bVpn\b', 'VPN'
    $friendly = $friendly -replace '\bMb\b', 'MB'
    $friendly = $friendly -replace '\bGb\b', 'GB'
    $friendly = $friendly -replace '\bC2 R\b', 'C2R'
    $friendly = $friendly -replace '\bWifi\b', 'Wi-Fi'
    $friendly = $friendly -replace '\bWi Fi\b', 'Wi-Fi'
    $friendly = $friendly -replace '\bJson\b', 'JSON'
    $friendly = $friendly -replace '\bMdm\b', 'MDM'
    $friendly = $friendly -replace '\bPki\b', 'PKI'
    $friendly = $friendly -replace '\bKfm\b', 'KFM'
    $friendly = $friendly -replace '\bIme\b', 'IME'
    $friendly = $friendly -replace '\bHklm\b', 'HKLM'
    $friendly = $friendly -replace '\bHkcu\b', 'HKCU'
    $friendly = $friendly -replace '\bMsi\b', 'MSI'
    $friendly = $friendly -replace '\bM365\b', 'M365'
    $friendly = $friendly -replace '\bDns\b', 'DNS'
    $friendly = $friendly -replace '\bUsb\b', 'USB'

    return $friendly
}

function Test-ConfigurationItemAdvanced {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $advancedNames = @(
        'ScriptPackageName',
        'ScriptName',
        'PurposeCategory'
    )

    return ($advancedNames -contains $Name)
}

function Get-ConfigurationHelpText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Kind,

        [Parameter(Mandatory = $true)]
        [string]$EditorKind,

        [Parameter(Mandatory = $true)]
        [string]$Expression
    )

    if ($Name -eq 'ScriptPackageName') {
        return 'Internal package/log identity. Usually leave this unchanged unless you intentionally rename the generated package and update matching references.'
    }

    if ($Name -eq 'ScriptName') {
        return 'Internal script identity. Usually leave this as Detect or Remediate.'
    }

    if ($Name -eq 'PurposeCategory') {
        return 'Repository category label used for documentation and local state paths. Usually leave unchanged.'
    }

    if ($EditorKind -eq 'Boolean') {
        return 'On/off choice. Pick Enabled/True or Disabled/False.'
    }

    if ($EditorKind -eq 'StringList') {
        return 'List of values. Enter one item per line; the tool converts it when generating.'
    }

    if ($EditorKind -eq 'Path') {
        return 'Windows path. You can use C:\Folder, $env:ProgramData\Folder, or %ProgramData%\Folder.'
    }

    if ($Name -match '(Path|Root|Folder|Directory|File)') {
        return 'Windows path or file name. Replace with the location used in your environment.'
    }

    if ($Name -match '(Url|Uri|Webhook)') {
        return 'URL used by this package. Replace sample or placeholder addresses with your approved URL.'
    }

    if ($Name -match '(Expected|Desired|Target|Required)') {
        return 'Target value the detection expects or the remediation applies. Change this to your approved baseline value.'
    }

    if ($Name -match '(Tenant|Domain)') {
        return 'Tenant or domain placeholder. Replace sample values such as contoso.com with your own value.'
    }

    if ($Name -match 'Printer') {
        return 'Printer value. Replace placeholder names with your organization printer name, queue, or path.'
    }

    if ($Name -match 'Vpn') {
        return 'VPN profile value. Replace placeholder names with your organization VPN profile name.'
    }

    if ($Name -match 'Service') {
        return 'Windows service name or service behavior used by the check.'
    }

    if ($Name -match '(Delay|Seconds|Minutes|Days|Count|Threshold|Limit|Size|Age)') {
        return 'Number used for timing, thresholds, limits, or counts.'
    }

    if ($EditorKind -eq 'Expression') {
        return 'Advanced value. Leave unchanged unless you are comfortable with the expression shown.'
    }

    return 'Editable value used by detection or remediation. Change it to match the target environment.'
}

function Get-ConfigurationOverviewText {
    param(
        [object[]]$Groups,

        [switch]$IncludeAdvanced
    )

    if ($null -eq $Groups -or @($Groups).Count -eq 0) {
        return 'No editable CONFIGURATION variables were found for this package.'
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $basicGroups = @($Groups | Where-Object { -not $_.IsAdvanced })
    $advancedGroups = @($Groups | Where-Object { $_.IsAdvanced })
    $visibleGroups = if ($IncludeAdvanced) { @($Groups) } else { @($basicGroups) }

    if ($IncludeAdvanced) {
        $lines.Add('Showing technician-facing and advanced/internal settings. Internal identity settings usually stay unchanged.')
    }
    elseif ($basicGroups.Count -eq 0) {
        $lines.Add('Only internal package identity settings were found. Most technicians can leave these unchanged.')
    }
    else {
        $lines.Add('Start with these values. The full editor is on the Configure tab.')
    }

    $lines.Add('')
    foreach ($group in $visibleGroups) {
        $suffix = if ($group.IsAdvanced) { ' (advanced)' } else { '' }
        $lines.Add("  $($group.FriendlyName)${suffix}: $($group.DisplayValue)")
    }

    if (-not $IncludeAdvanced -and $advancedGroups.Count -gt 0) {
        $lines.Add('')
        $lines.Add("$($advancedGroups.Count) advanced/internal setting(s) are hidden by default. Turn on Show advanced/internal settings below to view them.")
    }

    return ($lines -join [System.Environment]::NewLine)
}

function Get-ReadmeGuidanceText {
    param(
        [string]$ReadmeText
    )

    if ([string]::IsNullOrWhiteSpace($ReadmeText)) {
        return 'No README.md was found for this package.'
    }

    $headings = @(
        'What To Change First',
        'Prerequisites',
        'Customization',
        'Intune Deployment',
        'Intune Settings',
        'Expected Results',
        'Troubleshooting'
    )

    $sections = New-Object System.Collections.Generic.List[string]
    foreach ($heading in $headings) {
        $body = Get-MarkdownSection -Text $ReadmeText -Heading $heading
        if (-not [string]::IsNullOrWhiteSpace($body)) {
            $sections.Add("$heading`r`n$body")
        }
    }

    if ($sections.Count -eq 0) {
        return ConvertTo-WindowsTextBoxText -Text $ReadmeText
    }

    return ($sections -join ([System.Environment]::NewLine + [System.Environment]::NewLine))
}

function Apply-ConfigurationEditsToText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [object[]]$Items
    )

    $updated = $Text
    foreach ($item in ($Items | Sort-Object StartOffset -Descending)) {
        $expression = Convert-EditorValueToExpression -Item $item
        if ([string]::IsNullOrWhiteSpace($expression)) {
            throw "Configuration value '$($item.Name)' in '$($item.FileName)' is empty."
        }

        $replacement = "$($item.Indent)`$$($item.Name) = $expression"
        $length = $item.EndOffset - $item.StartOffset
        $updated = $updated.Remove($item.StartOffset, $length).Insert($item.StartOffset, $replacement)
    }

    return $updated
}

function Test-PowerShellSyntaxText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$parseErrors) | Out-Null

    if ($parseErrors -and $parseErrors.Count -gt 0) {
        $messages = $parseErrors | ForEach-Object { "$($_.Extent.StartLineNumber):$($_.Extent.StartColumnNumber) $($_.Message)" }
        throw "Generated '$DisplayName' has PowerShell syntax errors: $($messages -join '; ')"
    }
}

function Get-ModifiedScriptText {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Package,

        [Parameter(Mandatory = $true)]
        [string]$FileName,

        [Parameter(Mandatory = $true)]
        [object[]]$ConfigItems
    )

    $path = if ($FileName -eq 'Detect.ps1') { $Package.DetectPath } else { $Package.RemediatePath }
    $text = Read-TextFile -Path $path
    $items = @($ConfigItems | Where-Object { $_.FileName -eq $FileName })
    return Apply-ConfigurationEditsToText -Text $text -Items $items
}

function Test-DestinationIsSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    $root = [System.IO.Path]::GetFullPath($script:GeneratedRoot)
    $target = [System.IO.Path]::GetFullPath($Destination)
    if (-not $root.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $root += [System.IO.Path]::DirectorySeparatorChar
    }

    return $target.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)
}

function Export-RemediationPackage {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Package,

        [Parameter(Mandatory = $true)]
        [object[]]$ConfigItems,

        [Parameter(Mandatory = $true)]
        [string]$DestinationName,

        [switch]$Force
    )

    if ([string]::IsNullOrWhiteSpace($DestinationName)) {
        throw 'Export package name is required.'
    }

    if ($DestinationName -match '[\\/:*?"<>|]') {
        throw "Export package name '$DestinationName' contains characters that are not valid in a folder name."
    }

    if (-not (Test-Path -LiteralPath $script:GeneratedRoot -PathType Container)) {
        New-Item -Path $script:GeneratedRoot -ItemType Directory -Force | Out-Null
    }

    $destination = Join-Path -Path $script:GeneratedRoot -ChildPath $DestinationName
    if (-not (Test-DestinationIsSafe -Destination $destination)) {
        throw "Destination '$destination' is outside the generated package root."
    }

    $detectText = Get-ModifiedScriptText -Package $Package -FileName 'Detect.ps1' -ConfigItems $ConfigItems
    $remediateText = Get-ModifiedScriptText -Package $Package -FileName 'Remediate.ps1' -ConfigItems $ConfigItems

    Test-PowerShellSyntaxText -Text $detectText -DisplayName 'Detect.ps1'
    Test-PowerShellSyntaxText -Text $remediateText -DisplayName 'Remediate.ps1'

    if (Test-Path -LiteralPath $destination) {
        if (-not $Force) {
            throw "Destination '$destination' already exists."
        }

        Remove-Item -LiteralPath $destination -Recurse -Force
    }

    Copy-Item -LiteralPath $Package.FullPath -Destination $destination -Recurse -Force
    Write-TextFile -Path (Join-Path -Path $destination -ChildPath 'Detect.ps1') -Text $detectText
    Write-TextFile -Path (Join-Path -Path $destination -ChildPath 'Remediate.ps1') -Text $remediateText

    return $destination
}

function Find-PackageByName {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Packages,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $matches = @($Packages | Where-Object {
        $_.FolderName -eq $Name -or
        $_.Name -eq $Name -or
        $_.RelativePath -eq $Name
    })

    if ($matches.Count -eq 1) {
        return $matches[0]
    }

    if ($matches.Count -gt 1) {
        throw "Package name '$Name' matched more than one package."
    }

    throw "Package '$Name' was not found."
}

function Initialize-CliMode {
    $root = Get-DefaultRepositoryRoot
    if ([string]::IsNullOrWhiteSpace($root)) {
        throw 'No valid repository root was provided or discovered.'
    }

    $packages = Get-RemediationPackageIndex -RepositoryRoot $root

    if ($IndexOnly) {
        [pscustomobject]@{
            RepositoryRoot = $root
            RemediationPackages = @($packages).Count
        } | Format-List
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($ExportPackage)) {
        $package = Find-PackageByName -Packages $packages -Name $ExportPackage
        $items = Get-PackageConfigItems -Package $package
        $destinationName = if ([string]::IsNullOrWhiteSpace($ExportName)) { $package.FolderName } else { $ExportName }
        $destination = Export-RemediationPackage -Package $package -ConfigItems $items -DestinationName $destinationName -Force:$Force
        [pscustomobject]@{
            RepositoryRoot = $root
            Package = $package.FolderName
            ExportPath = $destination
        } | Format-List
    }
}

function Add-ComboItem {
    param(
        [System.Windows.Forms.ComboBox]$ComboBox,
        [string]$Value
    )

    [void]$ComboBox.Items.Add($Value)
}

function Set-Status {
    param(
        [string]$Message
    )

    if ($script:StatusLabel) {
        $script:StatusLabel.Text = $Message
    }
}

function Update-PackageFilters {
    if (-not $script:ListPackages) {
        return
    }

    $search = $script:TextSearch.Text.Trim().ToLowerInvariant()
    $purpose = [string]$script:ComboPurpose.SelectedItem
    $risk = [string]$script:ComboRisk.SelectedItem
    $context = [string]$script:ComboContext.SelectedItem

    $script:ListPackages.BeginUpdate()
    $script:ListPackages.Items.Clear()

    $filtered = New-Object System.Collections.Generic.List[object]
    foreach ($package in $script:Packages) {
        if (-not [string]::IsNullOrWhiteSpace($search) -and $package.SearchText -notlike "*$search*") {
            continue
        }

        if ($purpose -and $purpose -ne 'All' -and $package.Purpose -ne $purpose) {
            continue
        }

        if ($risk -and $risk -ne 'All' -and $package.Risk -ne $risk) {
            continue
        }

        if ($context -and $context -ne 'All' -and $package.Context -ne $context) {
            continue
        }

        $filtered.Add($package)
        $item = New-Object System.Windows.Forms.ListViewItem($package.Name)
        [void]$item.SubItems.Add($package.Purpose)
        [void]$item.SubItems.Add($package.Risk)
        [void]$item.SubItems.Add($package.Context)
        $item.Tag = $package
        [void]$script:ListPackages.Items.Add($item)
    }

    $script:FilteredPackages = @($filtered.ToArray())
    $script:ListPackages.EndUpdate()
    Set-Status "Showing $($script:FilteredPackages.Count) of $($script:Packages.Count) remediation packages."
}

function Load-RepositoryIntoGui {
    param(
        [string]$Root
    )

    try {
        $resolved = Resolve-FullPath -Path $Root
        $packages = Get-RemediationPackageIndex -RepositoryRoot $resolved
        $script:Packages = @($packages)
        $script:ActiveRepositoryRoot = $resolved
        $script:TextRepositoryRoot.Text = $resolved

        $script:ComboPurpose.Items.Clear()
        $script:ComboRisk.Items.Clear()
        $script:ComboContext.Items.Clear()
        Add-ComboItem -ComboBox $script:ComboPurpose -Value 'All'
        Add-ComboItem -ComboBox $script:ComboRisk -Value 'All'
        Add-ComboItem -ComboBox $script:ComboContext -Value 'All'

        $script:Packages | Select-Object -ExpandProperty Purpose -Unique | Sort-Object | ForEach-Object { Add-ComboItem -ComboBox $script:ComboPurpose -Value $_ }
        $script:Packages | Select-Object -ExpandProperty Risk -Unique | Sort-Object | ForEach-Object { Add-ComboItem -ComboBox $script:ComboRisk -Value $_ }
        $script:Packages | Select-Object -ExpandProperty Context -Unique | Sort-Object | ForEach-Object { Add-ComboItem -ComboBox $script:ComboContext -Value $_ }

        $script:ComboPurpose.SelectedIndex = 0
        $script:ComboRisk.SelectedIndex = 0
        $script:ComboContext.SelectedIndex = 0

        Save-GuiSettings -RepositoryRoot $resolved
        Update-PackageFilters
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Load failed', 'OK', 'Error') | Out-Null
        Set-Status 'Repository load failed.'
    }
}

function Update-ConfigurationGrid {
    $script:GridConfiguration.Rows.Clear()
    $showAdvanced = Get-ShowAdvancedSettings

    foreach ($group in $script:ConfigGroups) {
        if ($group.IsAdvanced -and -not $showAdvanced) {
            continue
        }

        $rowIndex = $script:GridConfiguration.Rows.Add(
            $group.FriendlyName,
            $group.AppliesTo,
            $group.DisplayValue,
            $group.HelpText
        )

        $row = $script:GridConfiguration.Rows[$rowIndex]
        $row.Tag = $group

        if ($group.IsAdvanced) {
            $row.DefaultCellStyle.ForeColor = [System.Drawing.Color]::DimGray
        }
    }

    if ($script:GridConfiguration.Rows.Count -gt 0) {
        $script:GridConfiguration.ClearSelection()
        $script:GridConfiguration.Rows[0].Selected = $true
        $script:GridConfiguration.CurrentCell = $script:GridConfiguration.Rows[0].Cells[0]
        Load-ConfigurationGroupIntoEditor -Group $script:GridConfiguration.Rows[0].Tag
    }
    else {
        Load-ConfigurationGroupIntoEditor -Group $null
    }
}

function Get-ShowAdvancedSettings {
    if ($script:CheckShowAdvancedOverview) {
        return [bool]$script:CheckShowAdvancedOverview.Checked
    }

    if ($script:CheckShowAdvanced) {
        return [bool]$script:CheckShowAdvanced.Checked
    }

    return $false
}

function Update-OverviewConfigurationText {
    if ($script:TextOverviewConfig) {
        $script:TextOverviewConfig.Text = ConvertTo-WindowsTextBoxText -Text (Get-ConfigurationOverviewText -Groups $script:ConfigGroups -IncludeAdvanced:(Get-ShowAdvancedSettings))
    }
}

function Set-ShowAdvancedSettings {
    param(
        [bool]$Checked
    )

    if ($script:SynchronizingAdvancedSetting) {
        return
    }

    $script:SynchronizingAdvancedSetting = $true
    try {
        if ($script:CheckShowAdvancedOverview -and $script:CheckShowAdvancedOverview.Checked -ne $Checked) {
            $script:CheckShowAdvancedOverview.Checked = $Checked
        }

        if ($script:CheckShowAdvanced -and $script:CheckShowAdvanced.Checked -ne $Checked) {
            $script:CheckShowAdvanced.Checked = $Checked
        }
    }
    finally {
        $script:SynchronizingAdvancedSetting = $false
    }

    Update-ConfigurationGrid
    Update-OverviewConfigurationText
}

function Update-OverviewDetails {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Package
    )

    if (-not $script:ListOverviewDetails) {
        return
    }

    $script:ListOverviewDetails.BeginUpdate()
    $script:ListOverviewDetails.Items.Clear()

    $details = [ordered]@{
        Name = $Package.Name
        Folder = $Package.FolderName
        Category = $Package.Purpose
        Risk = $Package.Risk
        Context = $Package.Context
        Status = $Package.Status
        Path = $Package.RelativePath
    }

    foreach ($entry in $details.GetEnumerator()) {
        $item = New-Object System.Windows.Forms.ListViewItem($entry.Key)
        [void]$item.SubItems.Add([string]$entry.Value)
        [void]$script:ListOverviewDetails.Items.Add($item)
    }

    $script:ListOverviewDetails.EndUpdate()
}

function Update-PreviewText {
    if ($null -eq $script:SelectedPackage) {
        return
    }

    try {
        $script:PreviewDetectText = Get-ModifiedScriptText -Package $script:SelectedPackage -FileName 'Detect.ps1' -ConfigItems $script:ConfigItems
        $script:PreviewRemediateText = Get-ModifiedScriptText -Package $script:SelectedPackage -FileName 'Remediate.ps1' -ConfigItems $script:ConfigItems

        Test-PowerShellSyntaxText -Text $script:PreviewDetectText -DisplayName 'Detect.ps1'
        Test-PowerShellSyntaxText -Text $script:PreviewRemediateText -DisplayName 'Remediate.ps1'

        $script:TextPreviewDetect.Text = ConvertTo-WindowsTextBoxText -Text $script:PreviewDetectText
        $script:TextPreviewRemediate.Text = ConvertTo-WindowsTextBoxText -Text $script:PreviewRemediateText
        $script:TextPreviewReadme.Text = ConvertTo-WindowsTextBoxText -Text (Read-TextFile -Path $script:SelectedPackage.ReadmePath)
        $script:TextPreviewScriptInfo.Text = ConvertTo-WindowsTextBoxText -Text (Read-TextFile -Path $script:SelectedPackage.ScriptInfoPath)

        Update-OverviewConfigurationText

        Set-Status "Preview ready for $($script:SelectedPackage.FolderName)."
    }
    catch {
        $script:TextPreviewDetect.Text = ''
        $script:TextPreviewRemediate.Text = ''
        Set-Status $_.Exception.Message
    }
}

function Load-PackageIntoGui {
    param(
        [object]$Package
    )

    $script:SelectedPackage = $Package
    $script:ConfigItems = Get-PackageConfigItems -Package $Package
    $script:ConfigGroups = Get-ConfigurationGroups -Items $script:ConfigItems
    $script:TextExportName.Text = $Package.FolderName
    $readmeText = Read-TextFile -Path $Package.ReadmePath
    $summary = Get-SafeText -Value $Package.Summary -Default (Get-MarkdownSection -Text $readmeText -Heading 'Summary')

    Update-OverviewDetails -Package $Package
    $script:TextOverviewSummary.Text = ConvertTo-WindowsTextBoxText -Text $summary
    Update-OverviewConfigurationText
    $script:TextOverviewGuidance.Text = ConvertTo-WindowsTextBoxText -Text (Get-ReadmeGuidanceText -ReadmeText $readmeText)

    Update-ConfigurationGrid
    Update-PreviewText
}

function Set-ConfigurationEditorMode {
    param(
        [string]$EditorKind
    )

    $script:TextSettingValue.Visible = $false
    $script:ComboBooleanValue.Visible = $false

    if ($EditorKind -eq 'Boolean') {
        $script:ComboBooleanValue.Visible = $true
    }
    else {
        $script:TextSettingValue.Visible = $true
        if ($EditorKind -eq 'StringList') {
            $script:TextSettingValue.Multiline = $true
            $script:TextSettingValue.ScrollBars = 'Vertical'
            $script:TextSettingValue.AcceptsReturn = $true
            $script:TextSettingValue.WordWrap = $false
        }
        else {
            $script:TextSettingValue.Multiline = $false
            $script:TextSettingValue.ScrollBars = 'None'
            $script:TextSettingValue.AcceptsReturn = $false
            $script:TextSettingValue.WordWrap = $false
        }
    }
}

function Load-ConfigurationGroupIntoEditor {
    param(
        [AllowNull()]
        [object]$Group
    )

    $script:SelectedConfigGroup = $Group
    $script:LoadingSettingEditor = $true
    try {
        if ($null -eq $Group) {
            $script:LabelSettingTitle.Text = 'Select a setting'
            $script:LabelSettingHelp.Text = 'Choose a row above to edit its value.'
            $script:LabelSettingTechnical.Text = ''
            $script:TextSettingValue.Text = ''
            $script:ComboBooleanValue.SelectedIndex = -1
            Set-ConfigurationEditorMode -EditorKind 'Text'
            return
        }

        $script:LabelSettingTitle.Text = "$($Group.FriendlyName)  [$($Group.AppliesTo)]"
        $script:LabelSettingHelp.Text = $Group.HelpText
        $script:LabelSettingTechnical.Text = "$($Group.TechnicalName) | Type: $($Group.EditorKind)"
        Set-ConfigurationEditorMode -EditorKind $Group.EditorKind

        if ($Group.EditorKind -eq 'Boolean') {
            if ([string]$Group.EditorValue -match '^(?i:true|\$true|yes|1|enabled|on)$') {
                $script:ComboBooleanValue.SelectedItem = 'Enabled / True'
            }
            else {
                $script:ComboBooleanValue.SelectedItem = 'Disabled / False'
            }
        }
        else {
            $script:TextSettingValue.Text = ConvertTo-WindowsTextBoxText -Text ([string]$Group.EditorValue)
        }
    }
    finally {
        $script:LoadingSettingEditor = $false
    }
}

function Update-SelectedConfigurationValue {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ($script:LoadingSettingEditor -or $null -eq $script:SelectedConfigGroup) {
        return
    }

    Set-ConfigurationGroupValue -Group $script:SelectedConfigGroup -Value $Value

    if ($script:GridConfiguration.CurrentRow -and $script:GridConfiguration.CurrentRow.Tag -eq $script:SelectedConfigGroup) {
        $script:GridConfiguration.CurrentRow.Cells['Value'].Value = $script:SelectedConfigGroup.DisplayValue
    }

    Update-PreviewText
}

function Reset-SelectedField {
    if ($script:GridConfiguration.SelectedRows.Count -eq 0 -and $script:GridConfiguration.CurrentRow) {
        $row = $script:GridConfiguration.CurrentRow
    }
    elseif ($script:GridConfiguration.SelectedRows.Count -gt 0) {
        $row = $script:GridConfiguration.SelectedRows[0]
    }
    else {
        return
    }

    $group = $row.Tag
    if ($null -eq $group) {
        return
    }

    Set-ConfigurationGroupValue -Group $group -Value $group.OriginalEditorValue
    $row.Cells['Value'].Value = $group.DisplayValue
    Load-ConfigurationGroupIntoEditor -Group $group
    Update-PreviewText
}

function Reset-AllFields {
    foreach ($group in $script:ConfigGroups) {
        Set-ConfigurationGroupValue -Group $group -Value $group.OriginalEditorValue
    }

    Update-ConfigurationGrid
    Update-PreviewText
}

function Export-SelectedPackageFromGui {
    if ($null -eq $script:SelectedPackage) {
        [System.Windows.Forms.MessageBox]::Show('Select a package first.', 'No package selected', 'OK', 'Information') | Out-Null
        return
    }

    $destinationName = $script:TextExportName.Text.Trim()
    $destination = Join-Path -Path $script:GeneratedRoot -ChildPath $destinationName

    if (Test-Path -LiteralPath $destination) {
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "Generated package '$destinationName' already exists. Overwrite it?",
            'Overwrite generated package',
            'YesNo',
            'Warning'
        )

        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }
    }

    try {
        $path = Export-RemediationPackage -Package $script:SelectedPackage -ConfigItems $script:ConfigItems -DestinationName $destinationName -Force
        $script:LastExportPath = $path
        Set-Status "Generated package: $path"
        [System.Windows.Forms.MessageBox]::Show("Generated package:`r`n$path", 'Generate complete', 'OK', 'Information') | Out-Null
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Generate failed', 'OK', 'Error') | Out-Null
        Set-Status 'Generate failed.'
    }
}

function New-ReadOnlyTextBox {
    param(
        [switch]$Wrap,

        [string]$FontName = 'Consolas',

        [int]$FontSize = 9,

        [string]$ScrollBars = 'Both'
    )

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Multiline = $true
    $textBox.ScrollBars = $ScrollBars
    $textBox.WordWrap = [bool]$Wrap
    $textBox.ReadOnly = $true
    $textBox.Dock = 'Fill'
    $textBox.Font = New-Object System.Drawing.Font($FontName, $FontSize)
    return $textBox
}

function New-OverviewGroupBox {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control]$Control
    )

    $groupBox = New-Object System.Windows.Forms.GroupBox
    $groupBox.Text = $Title
    $groupBox.Dock = 'Fill'
    $groupBox.Padding = New-Object System.Windows.Forms.Padding(8)
    $groupBox.Controls.Add($Control)
    return $groupBox
}

function Add-TabWithControl {
    param(
        [System.Windows.Forms.TabControl]$TabControl,
        [string]$Title,
        [System.Windows.Forms.Control]$Control
    )

    $tab = New-Object System.Windows.Forms.TabPage($Title)
    $tab.Controls.Add($Control)
    [void]$TabControl.TabPages.Add($tab)
    return $tab
}

function Start-Gui {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    if (-not (Test-Path -LiteralPath $script:GeneratedRoot -PathType Container)) {
        New-Item -Path $script:GeneratedRoot -ItemType Directory -Force | Out-Null
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Intune Remediation Picker'
    $form.StartPosition = 'CenterScreen'
    $form.Size = New-Object System.Drawing.Size(1220, 780)
    $form.MinimumSize = New-Object System.Drawing.Size(1000, 640)

    $rootPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $rootPanel.Dock = 'Fill'
    $rootPanel.ColumnCount = 1
    $rootPanel.RowCount = 4
    [void]$rootPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 44)))
    [void]$rootPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 44)))
    [void]$rootPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
    [void]$rootPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 40)))
    $form.Controls.Add($rootPanel)

    $repoPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $repoPanel.Dock = 'Fill'
    $repoPanel.ColumnCount = 4
    [void]$repoPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 110)))
    [void]$repoPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    [void]$repoPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 90)))
    [void]$repoPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 90)))
    [void]$rootPanel.Controls.Add($repoPanel, 0, 0)

    $repoLabel = New-Object System.Windows.Forms.Label
    $repoLabel.Text = 'Repository root'
    $repoLabel.Dock = 'Fill'
    $repoLabel.TextAlign = 'MiddleLeft'
    [void]$repoPanel.Controls.Add($repoLabel, 0, 0)

    $script:TextRepositoryRoot = New-Object System.Windows.Forms.TextBox
    $script:TextRepositoryRoot.Dock = 'Fill'
    $script:TextRepositoryRoot.Margin = New-Object System.Windows.Forms.Padding(3, 9, 3, 3)
    [void]$repoPanel.Controls.Add($script:TextRepositoryRoot, 1, 0)

    $buttonBrowse = New-Object System.Windows.Forms.Button
    $buttonBrowse.Text = 'Browse'
    $buttonBrowse.Dock = 'Fill'
    [void]$repoPanel.Controls.Add($buttonBrowse, 2, 0)

    $buttonLoad = New-Object System.Windows.Forms.Button
    $buttonLoad.Text = 'Load'
    $buttonLoad.Dock = 'Fill'
    [void]$repoPanel.Controls.Add($buttonLoad, 3, 0)

    $filterPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $filterPanel.Dock = 'Fill'
    $filterPanel.ColumnCount = 8
    [void]$filterPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 70)))
    [void]$filterPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    [void]$filterPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 70)))
    [void]$filterPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 180)))
    [void]$filterPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 45)))
    [void]$filterPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 110)))
    [void]$filterPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 60)))
    [void]$filterPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 120)))
    [void]$rootPanel.Controls.Add($filterPanel, 0, 1)

    $searchLabel = New-Object System.Windows.Forms.Label
    $searchLabel.Text = 'Search'
    $searchLabel.Dock = 'Fill'
    $searchLabel.TextAlign = 'MiddleLeft'
    [void]$filterPanel.Controls.Add($searchLabel, 0, 0)

    $script:TextSearch = New-Object System.Windows.Forms.TextBox
    $script:TextSearch.Dock = 'Fill'
    $script:TextSearch.Margin = New-Object System.Windows.Forms.Padding(3, 9, 8, 3)
    [void]$filterPanel.Controls.Add($script:TextSearch, 1, 0)

    $purposeLabel = New-Object System.Windows.Forms.Label
    $purposeLabel.Text = 'Category'
    $purposeLabel.Dock = 'Fill'
    $purposeLabel.TextAlign = 'MiddleLeft'
    [void]$filterPanel.Controls.Add($purposeLabel, 2, 0)

    $script:ComboPurpose = New-Object System.Windows.Forms.ComboBox
    $script:ComboPurpose.DropDownStyle = 'DropDownList'
    $script:ComboPurpose.Dock = 'Fill'
    $script:ComboPurpose.Margin = New-Object System.Windows.Forms.Padding(3, 8, 8, 3)
    [void]$filterPanel.Controls.Add($script:ComboPurpose, 3, 0)

    $riskLabel = New-Object System.Windows.Forms.Label
    $riskLabel.Text = 'Risk'
    $riskLabel.Dock = 'Fill'
    $riskLabel.TextAlign = 'MiddleLeft'
    [void]$filterPanel.Controls.Add($riskLabel, 4, 0)

    $script:ComboRisk = New-Object System.Windows.Forms.ComboBox
    $script:ComboRisk.DropDownStyle = 'DropDownList'
    $script:ComboRisk.Dock = 'Fill'
    $script:ComboRisk.Margin = New-Object System.Windows.Forms.Padding(3, 8, 8, 3)
    [void]$filterPanel.Controls.Add($script:ComboRisk, 5, 0)

    $contextLabel = New-Object System.Windows.Forms.Label
    $contextLabel.Text = 'Context'
    $contextLabel.Dock = 'Fill'
    $contextLabel.TextAlign = 'MiddleLeft'
    [void]$filterPanel.Controls.Add($contextLabel, 6, 0)

    $script:ComboContext = New-Object System.Windows.Forms.ComboBox
    $script:ComboContext.DropDownStyle = 'DropDownList'
    $script:ComboContext.Dock = 'Fill'
    $script:ComboContext.Margin = New-Object System.Windows.Forms.Padding(3, 8, 3, 3)
    [void]$filterPanel.Controls.Add($script:ComboContext, 7, 0)

    $split = New-Object System.Windows.Forms.SplitContainer
    $split.Dock = 'Fill'
    $split.Orientation = 'Vertical'
    $split.SplitterDistance = 430
    [void]$rootPanel.Controls.Add($split, 0, 2)

    $script:ListPackages = New-Object System.Windows.Forms.ListView
    $script:ListPackages.Dock = 'Fill'
    $script:ListPackages.View = 'Details'
    $script:ListPackages.FullRowSelect = $true
    $script:ListPackages.HideSelection = $false
    [void]$script:ListPackages.Columns.Add('Name', 210)
    [void]$script:ListPackages.Columns.Add('Category', 110)
    [void]$script:ListPackages.Columns.Add('Risk', 60)
    [void]$script:ListPackages.Columns.Add('Context', 70)
    $split.Panel1.Controls.Add($script:ListPackages)

    $rightTabs = New-Object System.Windows.Forms.TabControl
    $rightTabs.Dock = 'Fill'
    $split.Panel2.Controls.Add($rightTabs)

    $overviewPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $overviewPanel.Dock = 'Fill'
    $overviewPanel.ColumnCount = 1
    $overviewPanel.RowCount = 4
    $overviewPanel.Padding = New-Object System.Windows.Forms.Padding(6)
    [void]$overviewPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 158)))
    [void]$overviewPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 104)))
    [void]$overviewPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 160)))
    [void]$overviewPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))

    $script:ListOverviewDetails = New-Object System.Windows.Forms.ListView
    $script:ListOverviewDetails.Dock = 'Fill'
    $script:ListOverviewDetails.View = 'Details'
    $script:ListOverviewDetails.FullRowSelect = $true
    $script:ListOverviewDetails.HeaderStyle = 'Nonclickable'
    [void]$script:ListOverviewDetails.Columns.Add('Field', 95)
    [void]$script:ListOverviewDetails.Columns.Add('Value', 500)

    $script:TextOverviewSummary = New-ReadOnlyTextBox -Wrap -FontName 'Segoe UI' -ScrollBars 'Vertical'
    $overviewConfigPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $overviewConfigPanel.Dock = 'Fill'
    $overviewConfigPanel.ColumnCount = 1
    $overviewConfigPanel.RowCount = 2
    [void]$overviewConfigPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    [void]$overviewConfigPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 28)))
    [void]$overviewConfigPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))

    $script:CheckShowAdvancedOverview = New-Object System.Windows.Forms.CheckBox
    $script:CheckShowAdvancedOverview.Text = 'Show advanced/internal settings'
    $script:CheckShowAdvancedOverview.Dock = 'Fill'
    $script:CheckShowAdvancedOverview.TextAlign = 'MiddleLeft'
    [void]$overviewConfigPanel.Controls.Add($script:CheckShowAdvancedOverview, 0, 0)

    $script:TextOverviewConfig = New-ReadOnlyTextBox -Wrap -ScrollBars 'Vertical'
    [void]$overviewConfigPanel.Controls.Add($script:TextOverviewConfig, 0, 1)

    $script:TextOverviewGuidance = New-ReadOnlyTextBox -Wrap -FontName 'Segoe UI' -ScrollBars 'Vertical'

    [void]$overviewPanel.Controls.Add((New-OverviewGroupBox -Title 'Package Details' -Control $script:ListOverviewDetails), 0, 0)
    [void]$overviewPanel.Controls.Add((New-OverviewGroupBox -Title 'Description' -Control $script:TextOverviewSummary), 0, 1)
    [void]$overviewPanel.Controls.Add((New-OverviewGroupBox -Title 'Editable Configuration' -Control $overviewConfigPanel), 0, 2)
    [void]$overviewPanel.Controls.Add((New-OverviewGroupBox -Title 'Deployment And Troubleshooting Notes' -Control $script:TextOverviewGuidance), 0, 3)

    Add-TabWithControl -TabControl $rightTabs -Title 'Overview' -Control $overviewPanel | Out-Null

    $configurePanel = New-Object System.Windows.Forms.TableLayoutPanel
    $configurePanel.Dock = 'Fill'
    $configurePanel.RowCount = 4
    [void]$configurePanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 42)))
    [void]$configurePanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
    [void]$configurePanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 170)))
    [void]$configurePanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 42)))

    $configureIntro = New-Object System.Windows.Forms.Label
    $configureIntro.Dock = 'Fill'
    $configureIntro.TextAlign = 'MiddleLeft'
    $configureIntro.Text = 'Edit the values that should change for your environment. Leave internal settings hidden unless you need to rename package/script identity values.'
    [void]$configurePanel.Controls.Add($configureIntro, 0, 0)

    $script:GridConfiguration = New-Object System.Windows.Forms.DataGridView
    $script:GridConfiguration.Dock = 'Fill'
    $script:GridConfiguration.AllowUserToAddRows = $false
    $script:GridConfiguration.AllowUserToDeleteRows = $false
    $script:GridConfiguration.ReadOnly = $true
    $script:GridConfiguration.AutoSizeRowsMode = 'None'
    $script:GridConfiguration.RowTemplate.Height = 28
    $script:GridConfiguration.RowHeadersVisible = $false
    $script:GridConfiguration.SelectionMode = 'FullRowSelect'
    $script:GridConfiguration.MultiSelect = $false

    $colSetting = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colSetting.Name = 'Setting'
    $colSetting.HeaderText = 'Setting'
    $colSetting.ReadOnly = $true
    $colSetting.Width = 170
    [void]$script:GridConfiguration.Columns.Add($colSetting)

    $colFile = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colFile.Name = 'File'
    $colFile.HeaderText = 'Script'
    $colFile.ReadOnly = $true
    $colFile.Width = 95
    [void]$script:GridConfiguration.Columns.Add($colFile)

    $colValue = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colValue.Name = 'Value'
    $colValue.HeaderText = 'Current value'
    $colValue.Width = 260
    $colValue.ReadOnly = $true
    $colValue.DefaultCellStyle.WrapMode = 'False'
    [void]$script:GridConfiguration.Columns.Add($colValue)

    $colNotes = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colNotes.Name = 'Notes'
    $colNotes.HeaderText = 'Notes'
    $colNotes.ReadOnly = $true
    $colNotes.AutoSizeMode = 'Fill'
    $colNotes.DefaultCellStyle.WrapMode = 'False'
    [void]$script:GridConfiguration.Columns.Add($colNotes)

    [void]$configurePanel.Controls.Add($script:GridConfiguration, 0, 1)

    $editorGroup = New-Object System.Windows.Forms.GroupBox
    $editorGroup.Text = 'Selected Setting'
    $editorGroup.Dock = 'Fill'
    $editorGroup.Padding = New-Object System.Windows.Forms.Padding(8)

    $editorPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $editorPanel.Dock = 'Fill'
    $editorPanel.ColumnCount = 2
    $editorPanel.RowCount = 4
    [void]$editorPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 95)))
    [void]$editorPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    [void]$editorPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 24)))
    [void]$editorPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 42)))
    [void]$editorPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
    [void]$editorPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 24)))

    $settingTitleCaption = New-Object System.Windows.Forms.Label
    $settingTitleCaption.Text = 'Setting'
    $settingTitleCaption.Dock = 'Fill'
    $settingTitleCaption.TextAlign = 'MiddleLeft'
    [void]$editorPanel.Controls.Add($settingTitleCaption, 0, 0)

    $script:LabelSettingTitle = New-Object System.Windows.Forms.Label
    $script:LabelSettingTitle.Dock = 'Fill'
    $script:LabelSettingTitle.TextAlign = 'MiddleLeft'
    [void]$editorPanel.Controls.Add($script:LabelSettingTitle, 1, 0)

    $helpCaption = New-Object System.Windows.Forms.Label
    $helpCaption.Text = 'What it means'
    $helpCaption.Dock = 'Fill'
    $helpCaption.TextAlign = 'MiddleLeft'
    [void]$editorPanel.Controls.Add($helpCaption, 0, 1)

    $script:LabelSettingHelp = New-Object System.Windows.Forms.Label
    $script:LabelSettingHelp.Dock = 'Fill'
    $script:LabelSettingHelp.TextAlign = 'MiddleLeft'
    [void]$editorPanel.Controls.Add($script:LabelSettingHelp, 1, 1)

    $valueCaption = New-Object System.Windows.Forms.Label
    $valueCaption.Text = 'Value'
    $valueCaption.Dock = 'Fill'
    $valueCaption.TextAlign = 'MiddleLeft'
    [void]$editorPanel.Controls.Add($valueCaption, 0, 2)

    $valueEditorPanel = New-Object System.Windows.Forms.Panel
    $valueEditorPanel.Dock = 'Fill'

    $script:TextSettingValue = New-Object System.Windows.Forms.TextBox
    $script:TextSettingValue.Dock = 'Fill'
    $script:TextSettingValue.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $valueEditorPanel.Controls.Add($script:TextSettingValue)

    $script:ComboBooleanValue = New-Object System.Windows.Forms.ComboBox
    $script:ComboBooleanValue.DropDownStyle = 'DropDownList'
    $script:ComboBooleanValue.Dock = 'Top'
    [void]$script:ComboBooleanValue.Items.Add('Enabled / True')
    [void]$script:ComboBooleanValue.Items.Add('Disabled / False')
    $valueEditorPanel.Controls.Add($script:ComboBooleanValue)

    [void]$editorPanel.Controls.Add($valueEditorPanel, 1, 2)

    $technicalCaption = New-Object System.Windows.Forms.Label
    $technicalCaption.Text = 'Technical'
    $technicalCaption.Dock = 'Fill'
    $technicalCaption.TextAlign = 'MiddleLeft'
    [void]$editorPanel.Controls.Add($technicalCaption, 0, 3)

    $script:LabelSettingTechnical = New-Object System.Windows.Forms.Label
    $script:LabelSettingTechnical.Dock = 'Fill'
    $script:LabelSettingTechnical.TextAlign = 'MiddleLeft'
    $script:LabelSettingTechnical.ForeColor = [System.Drawing.Color]::DimGray
    [void]$editorPanel.Controls.Add($script:LabelSettingTechnical, 1, 3)

    $editorGroup.Controls.Add($editorPanel)
    [void]$configurePanel.Controls.Add($editorGroup, 0, 2)

    $configureFooter = New-Object System.Windows.Forms.TableLayoutPanel
    $configureFooter.Dock = 'Fill'
    $configureFooter.ColumnCount = 2
    [void]$configureFooter.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    [void]$configureFooter.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 230)))

    $script:CheckShowAdvanced = New-Object System.Windows.Forms.CheckBox
    $script:CheckShowAdvanced.Text = 'Show advanced/internal settings'
    $script:CheckShowAdvanced.Dock = 'Fill'
    $script:CheckShowAdvanced.TextAlign = 'MiddleLeft'
    [void]$configureFooter.Controls.Add($script:CheckShowAdvanced, 0, 0)

    $configureButtons = New-Object System.Windows.Forms.FlowLayoutPanel
    $configureButtons.Dock = 'Fill'
    $configureButtons.FlowDirection = 'RightToLeft'
    $buttonResetAll = New-Object System.Windows.Forms.Button
    $buttonResetAll.Text = 'Reset All'
    $buttonResetAll.Width = 100
    $buttonResetField = New-Object System.Windows.Forms.Button
    $buttonResetField.Text = 'Reset Field'
    $buttonResetField.Width = 100
    [void]$configureButtons.Controls.Add($buttonResetAll)
    [void]$configureButtons.Controls.Add($buttonResetField)
    [void]$configureFooter.Controls.Add($configureButtons, 1, 0)
    [void]$configurePanel.Controls.Add($configureFooter, 0, 3)
    Add-TabWithControl -TabControl $rightTabs -Title 'Configure' -Control $configurePanel | Out-Null

    $previewTabs = New-Object System.Windows.Forms.TabControl
    $previewTabs.Dock = 'Fill'
    $script:TextPreviewDetect = New-ReadOnlyTextBox
    $script:TextPreviewRemediate = New-ReadOnlyTextBox
    $script:TextPreviewReadme = New-ReadOnlyTextBox
    $script:TextPreviewScriptInfo = New-ReadOnlyTextBox
    Add-TabWithControl -TabControl $previewTabs -Title 'Detect.ps1' -Control $script:TextPreviewDetect | Out-Null
    Add-TabWithControl -TabControl $previewTabs -Title 'Remediate.ps1' -Control $script:TextPreviewRemediate | Out-Null
    Add-TabWithControl -TabControl $previewTabs -Title 'README.md' -Control $script:TextPreviewReadme | Out-Null
    Add-TabWithControl -TabControl $previewTabs -Title 'ScriptInfo.json' -Control $script:TextPreviewScriptInfo | Out-Null
    Add-TabWithControl -TabControl $rightTabs -Title 'Preview' -Control $previewTabs | Out-Null

    $exportPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $exportPanel.Dock = 'Fill'
    $exportPanel.ColumnCount = 5
    [void]$exportPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 120)))
    [void]$exportPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    [void]$exportPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 130)))
    [void]$exportPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 115)))
    [void]$exportPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 240)))
    [void]$rootPanel.Controls.Add($exportPanel, 0, 3)

    $exportLabel = New-Object System.Windows.Forms.Label
    $exportLabel.Text = 'Export folder'
    $exportLabel.Dock = 'Fill'
    $exportLabel.TextAlign = 'MiddleLeft'
    [void]$exportPanel.Controls.Add($exportLabel, 0, 0)

    $script:TextExportName = New-Object System.Windows.Forms.TextBox
    $script:TextExportName.Dock = 'Fill'
    $script:TextExportName.Margin = New-Object System.Windows.Forms.Padding(3, 8, 8, 3)
    [void]$exportPanel.Controls.Add($script:TextExportName, 1, 0)

    $buttonGenerate = New-Object System.Windows.Forms.Button
    $buttonGenerate.Text = 'Generate Package'
    $buttonGenerate.Dock = 'Fill'
    [void]$exportPanel.Controls.Add($buttonGenerate, 2, 0)

    $buttonOpenOutput = New-Object System.Windows.Forms.Button
    $buttonOpenOutput.Text = 'Open Output'
    $buttonOpenOutput.Dock = 'Fill'
    [void]$exportPanel.Controls.Add($buttonOpenOutput, 3, 0)

    $script:StatusLabel = New-Object System.Windows.Forms.Label
    $script:StatusLabel.Dock = 'Fill'
    $script:StatusLabel.TextAlign = 'MiddleLeft'
    $script:StatusLabel.Text = 'Ready.'
    [void]$exportPanel.Controls.Add($script:StatusLabel, 4, 0)

    $buttonBrowse.Add_Click({
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Select the script library root folder'
        if (-not [string]::IsNullOrWhiteSpace($script:TextRepositoryRoot.Text)) {
            $dialog.SelectedPath = $script:TextRepositoryRoot.Text
        }

        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:TextRepositoryRoot.Text = $dialog.SelectedPath
        }
    })

    $buttonLoad.Add_Click({ Load-RepositoryIntoGui -Root $script:TextRepositoryRoot.Text })
    $script:TextSearch.Add_TextChanged({ Update-PackageFilters })
    $script:ComboPurpose.Add_SelectedIndexChanged({ Update-PackageFilters })
    $script:ComboRisk.Add_SelectedIndexChanged({ Update-PackageFilters })
    $script:ComboContext.Add_SelectedIndexChanged({ Update-PackageFilters })

    $script:ListPackages.Add_SelectedIndexChanged({
        if ($script:ListPackages.SelectedItems.Count -gt 0) {
            Load-PackageIntoGui -Package $script:ListPackages.SelectedItems[0].Tag
        }
    })

    $script:GridConfiguration.Add_SelectionChanged({
        if ($script:GridConfiguration.CurrentRow) {
            $group = $script:GridConfiguration.CurrentRow.Tag
            if ($null -ne $group) {
                Load-ConfigurationGroupIntoEditor -Group $group
                Set-Status $group.HelpText
            }
        }
    })

    $script:TextSettingValue.Add_TextChanged({
        if (-not $script:LoadingSettingEditor) {
            Update-SelectedConfigurationValue -Value $script:TextSettingValue.Text
        }
    })

    $script:ComboBooleanValue.Add_SelectedIndexChanged({
        if (-not $script:LoadingSettingEditor -and $script:ComboBooleanValue.SelectedItem) {
            $value = if ([string]$script:ComboBooleanValue.SelectedItem -like 'Enabled*') { 'true' } else { 'false' }
            Update-SelectedConfigurationValue -Value $value
        }
    })

    $script:CheckShowAdvancedOverview.Add_CheckedChanged({ Set-ShowAdvancedSettings -Checked $script:CheckShowAdvancedOverview.Checked })
    $script:CheckShowAdvanced.Add_CheckedChanged({ Set-ShowAdvancedSettings -Checked $script:CheckShowAdvanced.Checked })
    $buttonResetField.Add_Click({ Reset-SelectedField })
    $buttonResetAll.Add_Click({ Reset-AllFields })
    $buttonGenerate.Add_Click({ Export-SelectedPackageFromGui })

    $buttonOpenOutput.Add_Click({
        $path = if (-not [string]::IsNullOrWhiteSpace($script:LastExportPath)) { $script:LastExportPath } else { $script:GeneratedRoot }
        if (Test-Path -LiteralPath $path) {
            Start-Process -FilePath explorer.exe -ArgumentList "`"$path`""
        }
    })

    $defaultRoot = Get-DefaultRepositoryRoot
    if (-not [string]::IsNullOrWhiteSpace($defaultRoot)) {
        $script:TextRepositoryRoot.Text = $defaultRoot
        Load-RepositoryIntoGui -Root $defaultRoot
    }

    [void]$form.ShowDialog()
}

if ($IndexOnly -or -not [string]::IsNullOrWhiteSpace($ExportPackage)) {
    Initialize-CliMode
    return
}

Start-Gui
