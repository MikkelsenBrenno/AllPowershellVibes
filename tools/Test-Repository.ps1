<#
.SYNOPSIS
    Validates repository structure, PowerShell syntax, and JSON syntax.

.DESCRIPTION
    Local maintainer tool for this Intune script library. The script checks
    required root files, required category folders, PowerShell parse errors,
    JSON parse errors, log naming identity values, and expected README files
    in script folders.

.NOTES
    Name:        Test-Repository.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     Local maintainer
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path
)

$ErrorActionPreference = 'Stop'
$failed = $false

function Write-Result {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('PASS', 'FAIL', 'WARN')]
        [string]$Status
    )

    Write-Output "[$Status] $Message"
}

function Add-Failure {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $script:failed = $true
    Write-Result -Message $Message -Status 'FAIL'
}

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

function Test-ContentContains {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$FailureMessage,

        [Parameter(Mandatory = $true)]
        [string]$SuccessMessage
    )

    if ($Content -match $Pattern) {
        Write-Result -Message $SuccessMessage -Status 'PASS'
    }
    else {
        Add-Failure -Message $FailureMessage
    }
}

function Test-ReadmeSection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$SectionName,

        [Parameter(Mandatory = $true)]
        [string]$ReadmePath
    )

    if ($Content -match "(?m)^##\s+$([regex]::Escape($SectionName))\s*$") {
        Write-Result -Message "README section '$SectionName' found in '$ReadmePath'." -Status 'PASS'
    }
    else {
        Add-Failure -Message "README section '$SectionName' missing in '$ReadmePath'."
    }
}

$requiredRootFiles = @(
    'README.md',
    'SCRIPT-CATALOG.md',
    'CONTRIBUTING.md',
    'LICENSE',
    '.gitignore'
)

$requiredFolders = @(
    'Detection-Remediation',
    'Custom-Compliance',
    'Intune-Platform-Scripts',
    'Win32-Packaged-Scripts',
    'docs',
    'templates',
    'tools',
    '.github'
)

$requiredScriptCategories = @(
    'Security',
    'Compliance',
    'Device-Configuration',
    'Applications',
    'Maintenance',
    'Endpoint-Health',
    'Networking',
    'User-Experience',
    'Inventory-Reporting',
    'Windows-Updates',
    'Browser-Management',
    'Remote-Work',
    'Identity-Access',
    'Printing',
    'Certificates-PKI',
    'Hardware-Drivers',
    'Power-Battery',
    'Backup-Recovery',
    'MDM-Enrollment',
    'Data-Protection',
    'Storage-Disk',
    'Troubleshooting-Support',
    'Peripheral-Devices',
    'Licensing-Activation'
)

$requiredScriptInfoFields = @(
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
    'Summary'
)

Write-Result -Message "Repository root: $RepositoryRoot" -Status 'PASS'

foreach ($file in $requiredRootFiles) {
    $path = Join-Path -Path $RepositoryRoot -ChildPath $file

    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Write-Result -Message "Found root file '$file'." -Status 'PASS'
    }
    else {
        Add-Failure -Message "Missing root file '$file'."
    }
}

foreach ($folder in $requiredFolders) {
    $path = Join-Path -Path $RepositoryRoot -ChildPath $folder

    if (Test-Path -LiteralPath $path -PathType Container) {
        Write-Result -Message "Found folder '$folder'." -Status 'PASS'
    }
    else {
        Add-Failure -Message "Missing folder '$folder'."
    }
}

$powershellFiles = Get-ChildItem -Path $RepositoryRoot -Recurse -Filter '*.ps1' -File

foreach ($file in $powershellFiles) {
    $tokens = $null
    $errors = $null

    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null

    $scriptContent = Get-Content -LiteralPath $file.FullName -Raw

    if ($scriptContent -match '(?m)^\s*\$TeamsWebhookUrl\s*=\s*[''"]https?://') {
        Add-Failure -Message "Possible committed Teams webhook URL in '$($file.FullName)'. Use an empty string or placeholder in source control."
    }

    if ($errors.Count -gt 0) {
        foreach ($errorItem in $errors) {
            Add-Failure -Message "PowerShell parse error in '$($file.FullName)': $($errorItem.Message)"
        }
    }
    else {
        Write-Result -Message "PowerShell syntax valid: '$($file.FullName)'." -Status 'PASS'
    }
}

$jsonFiles = Get-ChildItem -Path $RepositoryRoot -Recurse -Filter '*.json' -File

foreach ($file in $jsonFiles) {
    try {
        Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json | Out-Null
        Write-Result -Message "JSON syntax valid: '$($file.FullName)'." -Status 'PASS'
    }
    catch {
        Add-Failure -Message "JSON parse error in '$($file.FullName)': $($_.Exception.Message)"
    }
}

$categoryFolders = @(
    (Join-Path -Path $RepositoryRoot -ChildPath 'Detection-Remediation'),
    (Join-Path -Path $RepositoryRoot -ChildPath 'Custom-Compliance'),
    (Join-Path -Path $RepositoryRoot -ChildPath 'Intune-Platform-Scripts'),
    (Join-Path -Path $RepositoryRoot -ChildPath 'Win32-Packaged-Scripts')
)

foreach ($category in $categoryFolders) {
    if (-not (Test-Path -LiteralPath $category)) {
        continue
    }

    foreach ($scriptCategory in $requiredScriptCategories) {
        $scriptCategoryPath = Join-Path -Path $category -ChildPath $scriptCategory
        $scriptCategoryReadme = Join-Path -Path $scriptCategoryPath -ChildPath 'README.md'

        if (Test-Path -LiteralPath $scriptCategoryPath -PathType Container) {
            Write-Result -Message "Found purpose category '$scriptCategoryPath'." -Status 'PASS'
        }
        else {
            Add-Failure -Message "Missing purpose category '$scriptCategoryPath'."
            continue
        }

        if (Test-Path -LiteralPath $scriptCategoryReadme -PathType Leaf) {
            Write-Result -Message "Found README for purpose category '$scriptCategoryPath'." -Status 'PASS'
        }
        else {
            Add-Failure -Message "Missing README for purpose category '$scriptCategoryPath'."
        }

        $scriptFolders = Get-ChildItem -LiteralPath $scriptCategoryPath -Directory

        foreach ($scriptFolder in $scriptFolders) {
            $readme = Join-Path -Path $scriptFolder.FullName -ChildPath 'README.md'

            if (Test-Path -LiteralPath $readme -PathType Leaf) {
                Write-Result -Message "Found README for '$($scriptFolder.FullName)'." -Status 'PASS'

                $readmeContent = Get-Content -LiteralPath $readme -Raw
                $requiredReadmeSections = @(
                    'Summary',
                    'Prerequisites',
                    'Customization',
                    'Expected Results',
                    'Troubleshooting'
                )

                foreach ($requiredReadmeSection in $requiredReadmeSections) {
                    Test-ReadmeSection -Content $readmeContent -SectionName $requiredReadmeSection -ReadmePath $readme
                }

                if ($readmeContent -match '(?m)^##\s+(Intune Deployment|Intune Settings|Intune App Commands|Intune App Configuration)\s*$') {
                    Write-Result -Message "README includes Intune deployment/settings guidance in '$readme'." -Status 'PASS'
                }
                else {
                    Add-Failure -Message "README missing Intune deployment/settings guidance in '$readme'."
                }
            }
            else {
                Add-Failure -Message "Missing README for '$($scriptFolder.FullName)'."
            }

            $scriptInfoPath = Join-Path -Path $scriptFolder.FullName -ChildPath 'ScriptInfo.json'

            if (Test-Path -LiteralPath $scriptInfoPath -PathType Leaf) {
                try {
                    $scriptInfo = Get-Content -LiteralPath $scriptInfoPath -Raw | ConvertFrom-Json
                    Write-Result -Message "Found ScriptInfo metadata for '$($scriptFolder.FullName)'." -Status 'PASS'

                    foreach ($requiredScriptInfoField in $requiredScriptInfoFields) {
                        if (-not $scriptInfo.PSObject.Properties.Name.Contains($requiredScriptInfoField)) {
                            Add-Failure -Message "ScriptInfo field '$requiredScriptInfoField' missing in '$scriptInfoPath'."
                            continue
                        }

                        if ([string]::IsNullOrWhiteSpace([string]$scriptInfo.$requiredScriptInfoField)) {
                            Add-Failure -Message "ScriptInfo field '$requiredScriptInfoField' is empty in '$scriptInfoPath'."
                        }
                        else {
                            Write-Result -Message "ScriptInfo field '$requiredScriptInfoField' present in '$scriptInfoPath'." -Status 'PASS'
                        }
                    }

                    if ($scriptInfo.Purpose -ne $scriptCategory) {
                        Add-Failure -Message "ScriptInfo Purpose mismatch in '$scriptInfoPath'. Expected '$scriptCategory' but found '$($scriptInfo.Purpose)'."
                    }
                }
                catch {
                    Add-Failure -Message "ScriptInfo parse or validation error in '$scriptInfoPath': $($_.Exception.Message)"
                }
            }
            else {
                Add-Failure -Message "Missing ScriptInfo.json for '$($scriptFolder.FullName)'."
            }

            $scriptFiles = Get-ChildItem -LiteralPath $scriptFolder.FullName -Filter '*.ps1' -File

            foreach ($scriptFile in $scriptFiles) {
                $content = Get-Content -LiteralPath $scriptFile.FullName -Raw
                $expectedPackageName = $scriptFolder.Name
                $expectedScriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptFile.Name)

                $packageMatch = [regex]::Match($content, '(?m)^\s*\$ScriptPackageName\s*=\s*''([^'']+)''\s*$')
                $scriptNameMatch = [regex]::Match($content, '(?m)^\s*\$ScriptName\s*=\s*''([^'']+)''\s*$')
                $relativeScriptPath = Get-RelativePath -BasePath $RepositoryRoot -Path $scriptFile.FullName

                if (-not $packageMatch.Success) {
                    Add-Failure -Message "Missing ScriptPackageName in '$($scriptFile.FullName)'."
                }
                elseif ($packageMatch.Groups[1].Value -ne $expectedPackageName) {
                    Add-Failure -Message "ScriptPackageName mismatch in '$($scriptFile.FullName)'. Expected '$expectedPackageName' but found '$($packageMatch.Groups[1].Value)'."
                }
                else {
                    Write-Result -Message "ScriptPackageName matches folder for '$($scriptFile.FullName)'." -Status 'PASS'
                }

                if (-not $scriptNameMatch.Success) {
                    Add-Failure -Message "Missing ScriptName in '$($scriptFile.FullName)'."
                }
                elseif ($scriptNameMatch.Groups[1].Value -ne $expectedScriptName) {
                    Add-Failure -Message "ScriptName mismatch in '$($scriptFile.FullName)'. Expected '$expectedScriptName' but found '$($scriptNameMatch.Groups[1].Value)'."
                }
                else {
                    Write-Result -Message "ScriptName matches file name for '$($scriptFile.FullName)'." -Status 'PASS'
                }

                Test-ContentContains `
                    -Content $content `
                    -Pattern '(?m)^# CONFIGURATION\s*$' `
                    -FailureMessage "Missing CONFIGURATION section in '$($scriptFile.FullName)'." `
                    -SuccessMessage "CONFIGURATION section found in '$($scriptFile.FullName)'."

                Test-ContentContains `
                    -Content $content `
                    -Pattern 'CUSTOMIZE HERE' `
                    -FailureMessage "Missing CUSTOMIZE HERE guidance in '$($scriptFile.FullName)'." `
                    -SuccessMessage "CUSTOMIZE HERE guidance found in '$($scriptFile.FullName)'."

                Test-ContentContains `
                    -Content $content `
                    -Pattern '(?m)^# LOGGING\s*$' `
                    -FailureMessage "Missing LOGGING section in '$($scriptFile.FullName)'." `
                    -SuccessMessage "LOGGING section found in '$($scriptFile.FullName)'."

                Test-ContentContains `
                    -Content $content `
                    -Pattern '(?m)^# MAIN\s*$' `
                    -FailureMessage "Missing MAIN section in '$($scriptFile.FullName)'." `
                    -SuccessMessage "MAIN section found in '$($scriptFile.FullName)'."

                Test-ContentContains `
                    -Content $content `
                    -Pattern 'Write-ScriptMetadata' `
                    -FailureMessage "Missing Write-ScriptMetadata logging call or function in '$($scriptFile.FullName)'." `
                    -SuccessMessage "Script metadata logging present in '$($scriptFile.FullName)'."

                if ($relativeScriptPath -like 'Custom-Compliance\*\*\Discover.ps1') {
                    Test-ContentContains `
                        -Content $content `
                        -Pattern 'ConvertTo-Json\s+-Compress' `
                        -FailureMessage "Custom compliance discovery script should output compressed JSON in '$($scriptFile.FullName)'." `
                        -SuccessMessage "Custom compliance compressed JSON output found in '$($scriptFile.FullName)'."
                }

                if ($relativeScriptPath -like 'Win32-Packaged-Scripts\*\*\Detect.ps1') {
                    Test-ContentContains `
                        -Content $content `
                        -Pattern 'Write-Output' `
                        -FailureMessage "Win32 detection script should write STDOUT when detected in '$($scriptFile.FullName)'." `
                        -SuccessMessage "Win32 detection STDOUT path found in '$($scriptFile.FullName)'."
                }
            }
        }
    }
}

if ($failed) {
    Write-Output 'Repository validation failed.'
    exit 1
}

Write-Output 'Repository validation completed successfully.'
exit 0
