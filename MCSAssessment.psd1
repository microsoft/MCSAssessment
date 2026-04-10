@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'MCSAssessment.psm1'

    # Version number of this module.
    ModuleVersion = '0.4.0'

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author = 'Claudio Merola'

    # Company or vendor of this module
    CompanyName = 'Microsoft'

    # Copyright statement for this module
    Copyright = '(c) Microsoft Corporation. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'MCS Assessment module for evaluating and analyzing Mission Critical Services for Azure Workloads.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.1'

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @(
        'src/Assessment/Cleanup.psm1',
        'src/Assessment/Compress.psm1',
        'src/Assessment/Inventory.psm1',
        'src/Assessment/MCSB.psm1',
        'src/Assessment/MDC.psm1',
        'src/Assessment/PSRule.psm1',
        'src/Assessment/WARA.psm1',
        'src/Report/ConnectAzure.psm1',
        'src/Report/Metro.psm1',
        'src/Report/PPTTemplate.psm1',
        'src/Report/Slide1.psm1',
        'src/Report/Slide6.psm1',
        'src/Report/Slide7.psm1',
        'src/Report/Build-MCSHighImpactSlide.psm1',
        'src/Report/Build-MCSMediumImpactSlide.psm1',
        'src/Report/Build-MCSLowImpactSlide.psm1',
        'src/Report/SubscriptionList.psm1')

    # Functions to export from this module
    FunctionsToExport = @('*')

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @('ImportExcel','AzureResourceInventory','Az.CostManagement','WARA','PSRule','Metro.AI')

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module to aid in module discovery
            Tags = @('MCS', 'Assessment', 'Cloud', 'Microsoft')

            # A URL to the license for this module
            # LicenseUri = ''

            # A URL to the main website for this project
            # ProjectUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''

            # Prerelease string of this module
            #Prerelease = ''
        }
    }
}