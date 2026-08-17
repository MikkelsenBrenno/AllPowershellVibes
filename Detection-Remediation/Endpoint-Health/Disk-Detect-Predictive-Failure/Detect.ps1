<#
.SYNOPSIS
    Detects disk predictive failure signals.

.DESCRIPTION
    Intune Remediations detection script. The script checks Windows SMART
    predictive failure data for the disk that contains the Windows installation.
    It optionally uses Windows disk health as a fallback signal for that same
    OS disk. It exits 1 when the Windows disk reports predictive failure or an
    unhealthy state that should be investigated.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      No predictive disk failure detected
    Exit 1:      Predictive disk failure or unhealthy disk state detected

.CUSTOMIZATION
    Update values in the CONFIGURATION section before deployment.
#>

#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

# =========================
# CONFIGURATION
# =========================

# CUSTOMIZE HERE.
# Keep every value an admin is expected to change in this section.
# Common examples: file paths, registry paths, service names, URLs,
# tenant-specific labels, expected values, and validation timing.

# Keep these names aligned with the folder and script file.
# Logs are written to Logs\<ScriptPackageName>\<ScriptName>.log.
$ScriptPackageName = 'Disk-Detect-Predictive-Failure'
$ScriptName = 'Detect'

# Uses MSStorageDriver_FailurePredictStatus from root\wmi.
# Leave enabled unless your hardware vendor provides a better source.
$CheckSmartPredictiveFailure = $true

# Target only the drive where Windows is installed. The default resolves from
# $env:SystemDrive, which is normally C:.
$TargetDriveLetter = ($env:SystemDrive -replace ':', '')

# Uses Win32_DiskDrive and Get-Disk as fallback health sources for the OS disk.
# This helps on devices where SMART predictive data is limited or unavailable.
$CheckDiskHealthFallback = $true

# Disk health states that should be treated as noncompliant.
$UnhealthyDiskHealthStatuses = @('Warning', 'Unhealthy')

# Disk operational states that should be treated as noncompliant.
$UnhealthyDiskOperationalStatuses = @('Predictive Failure')

# Win32_DiskDrive status values that should be treated as noncompliant.
$UnhealthyWin32DiskStatuses = @('Pred Fail', 'Error', 'Degraded')

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log {
    if (-not (Test-Path -LiteralPath $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "$timestamp [$Level] $Message"
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

function New-DiskFinding {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [AllowEmptyString()]
        [string]$SerialNumber = '',

        [AllowEmptyString()]
        [string]$BusType = '',

        [AllowEmptyString()]
        [string]$HealthStatus = '',

        [AllowEmptyString()]
        [string]$OperationalStatus = '',

        [Parameter(Mandatory = $true)]
        [string]$Reason
    )

    return [PSCustomObject]@{
        Source            = $Source
        Name              = $Name
        SerialNumber      = $SerialNumber
        BusType           = $BusType
        HealthStatus      = $HealthStatus
        OperationalStatus = $OperationalStatus
        Reason            = $Reason
    }
}

function ConvertTo-ComparableDeviceId {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    return (($Text.ToUpperInvariant()) -replace '[^A-Z0-9]', '')
}

function Get-NormalizedDriveLetter {
    param(
        [AllowEmptyString()]
        [string]$DriveLetter
    )

    $normalizedDriveLetter = ($DriveLetter -replace '[:\\]', '').Trim()

    if ([string]::IsNullOrWhiteSpace($normalizedDriveLetter)) {
        $normalizedDriveLetter = (($env:SystemDrive -replace '[:\\]', '').Trim())
    }

    if ([string]::IsNullOrWhiteSpace($normalizedDriveLetter)) {
        $normalizedDriveLetter = 'C'
    }

    return $normalizedDriveLetter.Substring(0, 1).ToUpperInvariant()
}

function Get-TargetDiskDrives {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriveLetter
    )

    $normalizedDriveLetter = Get-NormalizedDriveLetter -DriveLetter $DriveLetter
    $logicalDiskId = "${normalizedDriveLetter}:"

    Write-Log -Message "Resolving target Windows drive '$logicalDiskId' to backing physical disk."

    $logicalDisk = Get-CimInstance -ClassName 'Win32_LogicalDisk' -Filter "DeviceID='$logicalDiskId'" -ErrorAction Stop

    if ($null -eq $logicalDisk) {
        throw "Logical disk '$logicalDiskId' was not found."
    }

    $partitions = @(Get-CimAssociatedInstance -InputObject $logicalDisk -Association 'Win32_LogicalDiskToPartition' -ErrorAction Stop)

    if ($partitions.Count -eq 0) {
        throw "No disk partition association was found for '$logicalDiskId'."
    }

    $diskDrivesByDeviceId = @{}

    foreach ($partition in $partitions) {
        $diskDrives = @(Get-CimAssociatedInstance -InputObject $partition -Association 'Win32_DiskDriveToDiskPartition' -ErrorAction Stop)

        foreach ($diskDrive in $diskDrives) {
            $deviceId = [string]$diskDrive.DeviceID

            if (-not [string]::IsNullOrWhiteSpace($deviceId) -and -not $diskDrivesByDeviceId.ContainsKey($deviceId)) {
                $diskDrivesByDeviceId[$deviceId] = $diskDrive
            }
        }
    }

    if ($diskDrivesByDeviceId.Count -eq 0) {
        throw "No physical disk association was found for '$logicalDiskId'."
    }

    foreach ($diskDrive in $diskDrivesByDeviceId.Values) {
        Write-Log -Message "Target disk resolved. DeviceID='$($diskDrive.DeviceID)'; Index='$($diskDrive.Index)'; Model='$($diskDrive.Model)'; Serial='$($diskDrive.SerialNumber)'; PNPDeviceID='$($diskDrive.PNPDeviceID)'; Status='$($diskDrive.Status)'."
    }

    return @($diskDrivesByDeviceId.Values)
}

function Get-MatchingTargetDiskDriveForSmartInstance {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceName,

        [Parameter(Mandatory = $true)]
        [object[]]$TargetDiskDrives
    )

    $smartComparable = ConvertTo-ComparableDeviceId -Text $InstanceName

    foreach ($diskDrive in $TargetDiskDrives) {
        $diskComparable = ConvertTo-ComparableDeviceId -Text ([string]$diskDrive.PNPDeviceID)

        if (-not [string]::IsNullOrWhiteSpace($diskComparable) -and ($smartComparable -like "*$diskComparable*" -or $diskComparable -like "*$smartComparable*")) {
            return $diskDrive
        }
    }

    return $null
}

function Get-SmartPredictiveFailureFindings {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$TargetDiskDrives
    )

    $findings = New-Object System.Collections.Generic.List[object]

    if (-not $CheckSmartPredictiveFailure) {
        Write-Log -Message 'SMART predictive failure check is disabled.'
        return @($findings)
    }

    try {
        $smartStatuses = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'MSStorageDriver_FailurePredictStatus' -ErrorAction Stop)
        Write-Log -Message "SMART predictive status instances found: $($smartStatuses.Count)."

        foreach ($smartStatus in $smartStatuses) {
            $instanceName = [string]$smartStatus.InstanceName
            $predictFailure = [bool]$smartStatus.PredictFailure
            $targetDiskDrive = Get-MatchingTargetDiskDriveForSmartInstance -InstanceName $instanceName -TargetDiskDrives $TargetDiskDrives

            if ($null -eq $targetDiskDrive) {
                Write-Log -Message "Skipping SMART instance '$instanceName' because it does not match the target Windows disk."
                continue
            }

            Write-Log -Message "Target Windows disk SMART instance '$instanceName' reports PredictFailure='$predictFailure'."

            if ($predictFailure) {
                $findings.Add((New-DiskFinding `
                    -Source 'MSStorageDriver_FailurePredictStatus' `
                    -Name ([string]$targetDiskDrive.Model) `
                    -SerialNumber ([string]$targetDiskDrive.SerialNumber) `
                    -BusType ([string]$targetDiskDrive.InterfaceType) `
                    -Reason 'SMART predictive failure is true.'))
            }
        }
    }
    catch {
        Write-Log -Message "SMART predictive failure query failed. $($_.Exception.Message)" -Level 'WARN'
    }

    return @($findings)
}

function Get-DiskHealthFallbackFindings {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$TargetDiskDrives
    )

    $findings = New-Object System.Collections.Generic.List[object]

    if (-not $CheckDiskHealthFallback) {
        Write-Log -Message 'Disk health fallback is disabled.'
        return @($findings)
    }

    foreach ($diskDrive in $TargetDiskDrives) {
        $name = [string]$diskDrive.Model
        $serialNumber = [string]$diskDrive.SerialNumber
        $busType = [string]$diskDrive.InterfaceType
        $win32Status = [string]$diskDrive.Status

        Write-Log -Message "Target Windows disk fallback status. DeviceID='$($diskDrive.DeviceID)'; Index='$($diskDrive.Index)'; Model='$name'; Serial='$serialNumber'; InterfaceType='$busType'; Win32Status='$win32Status'."

        if ($UnhealthyWin32DiskStatuses -contains $win32Status) {
            $findings.Add((New-DiskFinding `
                -Source 'Win32_DiskDrive' `
                -Name $name `
                -SerialNumber $serialNumber `
                -BusType $busType `
                -HealthStatus $win32Status `
                -Reason "Win32_DiskDrive status is '$win32Status'."))
        }

        if (-not (Get-Command -Name Get-Disk -ErrorAction SilentlyContinue)) {
            Write-Log -Message 'Get-Disk is not available on this device.' -Level 'WARN'
            continue
        }

        try {
            $storageDisk = Get-Disk -Number ([int]$diskDrive.Index) -ErrorAction Stop
            $healthStatus = [string]$storageDisk.HealthStatus
            $operationalStatus = (($storageDisk.OperationalStatus | ForEach-Object { [string]$_ }) -join ', ')
            $storageBusType = [string]$storageDisk.BusType

            Write-Log -Message "Target Windows disk Get-Disk status. Number='$($storageDisk.Number)'; FriendlyName='$($storageDisk.FriendlyName)'; Serial='$($storageDisk.SerialNumber)'; BusType='$storageBusType'; HealthStatus='$healthStatus'; OperationalStatus='$operationalStatus'."

            if ($UnhealthyDiskHealthStatuses -contains $healthStatus) {
                $findings.Add((New-DiskFinding `
                    -Source 'Get-Disk' `
                    -Name ([string]$storageDisk.FriendlyName) `
                    -SerialNumber ([string]$storageDisk.SerialNumber) `
                    -BusType $storageBusType `
                    -HealthStatus $healthStatus `
                    -OperationalStatus $operationalStatus `
                    -Reason "Disk health status is '$healthStatus'."))

                continue
            }

            foreach ($unhealthyOperationalStatus in $UnhealthyDiskOperationalStatuses) {
                if ($operationalStatus -like "*$unhealthyOperationalStatus*") {
                    $findings.Add((New-DiskFinding `
                        -Source 'Get-Disk' `
                        -Name ([string]$storageDisk.FriendlyName) `
                        -SerialNumber ([string]$storageDisk.SerialNumber) `
                        -BusType $storageBusType `
                        -HealthStatus $healthStatus `
                        -OperationalStatus $operationalStatus `
                        -Reason "Disk operational status includes '$unhealthyOperationalStatus'."))

                    break
                }
            }
        }
        catch {
            Write-Log -Message "Get-Disk fallback query failed for target disk index '$($diskDrive.Index)'. $($_.Exception.Message)" -Level 'WARN'
        }
    }

    return @($findings)
}

function Convert-FindingToText {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Finding
    )

    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add("Source='$($Finding.Source)'")
    $parts.Add("Name='$($Finding.Name)'")

    if (-not [string]::IsNullOrWhiteSpace($Finding.SerialNumber)) {
        $parts.Add("Serial='$($Finding.SerialNumber)'")
    }

    if (-not [string]::IsNullOrWhiteSpace($Finding.BusType)) {
        $parts.Add("BusType='$($Finding.BusType)'")
    }

    if (-not [string]::IsNullOrWhiteSpace($Finding.HealthStatus)) {
        $parts.Add("HealthStatus='$($Finding.HealthStatus)'")
    }

    if (-not [string]::IsNullOrWhiteSpace($Finding.OperationalStatus)) {
        $parts.Add("OperationalStatus='$($Finding.OperationalStatus)'")
    }

    $parts.Add("Reason='$($Finding.Reason)'")

    return ($parts -join '; ')
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. TargetDriveLetter='$TargetDriveLetter'; CheckSmartPredictiveFailure='$CheckSmartPredictiveFailure'; CheckDiskHealthFallback='$CheckDiskHealthFallback'."

    $targetDiskDrives = @(Get-TargetDiskDrives -DriveLetter $TargetDriveLetter)
    $findings = @()
    $findings += @(Get-SmartPredictiveFailureFindings -TargetDiskDrives $targetDiskDrives)
    $findings += @(Get-DiskHealthFallbackFindings -TargetDiskDrives $targetDiskDrives)

    if ($findings.Count -gt 0) {
        Write-Log -Message "Not compliant. Disk predictive failure findings detected: $($findings.Count)." -Level 'WARN'

        foreach ($finding in $findings) {
            Write-Log -Message (Convert-FindingToText -Finding $finding) -Level 'WARN'
        }

        Write-Output "Not compliant. Windows disk predictive failure or unhealthy disk state detected. Findings: $($findings.Count)."
        exit 1
    }

    Write-Log -Message 'Compliant. No Windows disk predictive failure detected.'
    Write-Output 'Compliant. No Windows disk predictive failure detected.'
    exit 0
}
catch {
    try {
        Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Not compliant. Disk predictive failure detection could not complete.'
    exit 1
}

