@{
    RootModule = 'ExampleModule.psm1'
    ModuleVersion = '1.0.0'
    GUID = '2b199d16-6c3c-45b4-8c9d-0d2705972c16'
    Author = 'IT'
    CompanyName = 'Contoso'
    Copyright = '(c) Contoso. All rights reserved.'
    Description = 'Example local PowerShell module payload. Replace before production packaging.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Get-ExampleModuleStatus')
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Intune', 'Template')
            ProjectUri = ''
        }
    }
}
