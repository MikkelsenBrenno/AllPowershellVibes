function Get-ExampleModuleStatus {
    [CmdletBinding()]
    param()

    [PSCustomObject]@{
        ModuleName = 'ExampleModule'
        Status = 'Installed'
        Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
}

Export-ModuleMember -Function Get-ExampleModuleStatus
