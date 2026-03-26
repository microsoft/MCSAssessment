<#
.SYNOPSIS
    Consolidated assessment script for Azure workloads, leveraging multiple tools to gather security and optimization recommendations.
 
.DESCRIPTION
    This script runs all the necessary tools to compose the assessment of a workload in Azure, including Azure Resource Inventory, WARA, Defender for Cloud, Security Benchmark and PSRule. The output is a table in CSV format that can be easily analyzed and shared.
 
.PARAMETER TenantID
    Specify the tenant ID of the workload.
 
.PARAMETER SubscriptionID
    Use this parameter to specify Subscription in the Tenant
 
.PARAMETER WorkloadName
    Use this parameter to specify the name of the workload. This will be used as suffix for the generated files.
 
.PARAMETER SkipCompress
    Use this parameter to skip the final compression of the generated files in a ZIP file.
 
.PARAMETER SkipARI
    Use this parameter to skip the Azure Resource Inventory collection.
 
.PARAMETER SkipWARA
    Use this parameter to skip the WARA recommendations collection.
 
.PARAMETER SkipMDC
    Use this parameter to skip the MDC collection.
 
.PARAMETER SkipMCSB
    Use this parameter to skip the MCSB collection.
 
.PARAMETER SkipPSRule
    Use this parameter to skip the PSRule collection.
 
.PARAMETER FullWARA
    By default, only the WARA recommendations with automated remediation are included in the output. Use this parameter to include all the WARA recommendations, even those without automated remediation (non-automated ones will have "N/A" in the "Potential Benefit" column of the output).
 
.EXAMPLE
    Default utilization. Specify tenant and Subscriptions that are part of the workload:
    PS C:\> Invoke-MCSAssessment -TenantID "00000000-0000-0000-0000-000000000000" -SubscriptionID 00000000-0000-0000-0000-000000000000,11111111-1111-1111-1111-111111111111 -WorkloadName "XYZ - Prod"
 
    Runs the script but skips Azure Resource Inventory collection:
    PS C:\> Invoke-MCSAssessment -TenantID "00000000-0000-0000-0000-000000000000" -SubscriptionID 00000000-0000-0000-0000-000000000000,11111111-1111-1111-1111-111111111111 -SkipARI -WorkloadName "XYZ - Prod"
 
    Runs the script and include all WARA recommendations (not only the automated ones):
    PS C:\> Invoke-MCSAssessment -TenantID "00000000-0000-0000-0000-000000000000" -SubscriptionID 00000000-0000-0000-0000-000000000000,11111111-1111-1111-1111-111111111111 -FullWARA -WorkloadName "XYZ - Prod"
 
.NOTES
    AUTHORS: Claudio Merola | Azure Infrastucture/Automation/Devops/Governance
 
    Copyright (c) 2025 Microsoft Corporation. All rights reserved.
 
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
 
.LINK
    Official Repository: TBD
#>
function Invoke-MCSAssessment {
    Param(
    [Alias("Tenant","Tenants")]
    [string]$TenantID,
    [Alias("Subscription","Subscriptions","Subs")]
    [String[]]$SubscriptionID,
    [Alias("Workload","Workloads")]
    [String]$WorkloadName = "Default_Workload",
    [switch]$SkipCompress,
    [switch]$SkipARI,
    [switch]$SkipWARA,
    [switch]$SkipMDC,
    [switch]$SkipMCSB,
    [switch]$SkipPSRule,
    [switch]$FullWARA
    )

    # WARA Files
    $RecommendationResourceTypesUri = 'https://azure.github.io/WARA-Build/objects/WARAinScopeResTypes.csv'
    $RecommendationDataUri = 'https://azure.github.io/WARA-Build/objects/recommendations.json'

    Write-Host "Setting Variables.."
    $workingDirectory = (Get-Location).Path
    Write-Host "Working Directory: $workingDirectory"
    if ($workingDirectory -eq "C:\") {
        Write-Host "Error: Working Directory cannot be the root of C:\" -ForegroundColor Red
        exit 1
    }

    Write-Host "Validating Parameters..."
    if (-Not $TenantID) {
        Write-Host "Error: No TenantID" -ForegroundColor Red
        exit 1
    }

    if (-Not $SubscriptionID) {
        Write-Host "Error: No SubscriptionID" -ForegroundColor Red
        exit 1
    }

    if ($SkipARI.IsPresent) {
        Write-Host "Skipping ARI Data Collection as per user request." -ForegroundColor Yellow
    } else {
        Write-Host "Starting ARI Data Collection for Workload: $WorkloadName"
        Invoke-ARI -ReportDir $workingDirectory -ReportName $WorkloadName -NoAutoUpdate -DiagramFullEnvironment -TenantId $TenantID -SubscriptionId $SubscriptionID -Debug -IncludeCosts -Lite
    }

    if ($SkipWARA.IsPresent) {
        Write-Host "Skipping WARA Data Collection as per user request." -ForegroundColor Yellow
    } else {
        Write-Host "Starting WARA Data Collection for Workload: $WorkloadName"
        Start-WARACollector -tenantid $TenantID -subscriptionid @($SubscriptionID) -Debug

        $WARAFile = Get-ChildItem -Path $workingDirectory -Filter "WARA-File*.json"

        $JSONResources = Get-Item -Path $WARAFile
        $JSONResources = $JSONResources.FullName
        $JSONContent = Get-Content -Path $JSONResources | ConvertFrom-Json

        $RootTypes = Invoke-RestMethod $RecommendationResourceTypesUri | ConvertFrom-Csv
        $RootTypes = $RootTypes | Where-Object { $_.InAprlAndOrAdvisor -eq 'yes' }

        $RecommendationObject = Invoke-RestMethod $RecommendationDataUri

        Write-Host "Count of WARA Recommendations: $($RecommendationObject.Count)"

        $ResourceRecommendations = $RecommendationObject | Where-Object { [string]::IsNullOrEmpty($_.tags) }

        $ResourceCollection = @()

        # First loop through the recommendations to get the impacted resources
        foreach ($Recom in $ResourceRecommendations) {
            $Resources = $JSONContent.ImpactedResources| Where-Object { ($_.recommendationId -eq $Recom.aprlGuid) }

            # If the recommendation is not a Custom Recommendation, we need to validate if the resources are not already in the tmp array (from a previous loop of a Custom Recommendation)
            if ([string]::IsNullOrEmpty($Resources) -and $Recom.aprlGuid -notin $tmp.Guid -and -not $Recom.checkName) {
                $Resources = $JSONContent.ImpactedResources | Where-Object { ($_.recommendationId -eq $Recom.aprlGuid) }
            }

            foreach ($Resource in $Resources) {
                if($FullWARA.IsPresent){
                    $ResObj = [PSCustomObject]@{
                            'Recommendation Guid'        = $Recom.aprlGuid
                            'Recommendation Title'       = $Recom.description
                            'Description'                = $Recom.longDescription
                            'Priority'                   = $Recom.recommendationImpact
                            'Customer-facing annotation' = ""
                            'Internal-facing notes'      = ($Recom.learnMoreLink.url -join " `n")
                            'Potential Benefit'          = $Recommendation.'Potential Benefit'
                            'Resource Type'              = $Resource.type
                            'Resource ID'                = $Resource.id
                        }

                    $ResourceCollection += $ResObj
                }
                else
                {
                    if ($Resource.validationAction -eq 'APRL - Queries') {
                        $ResObj = [PSCustomObject]@{
                                'Recommendation Guid'        = $Recom.aprlGuid
                                'Recommendation Title'       = $Recom.description
                                'Description'                = $Recom.longDescription
                                'Priority'                   = $Recom.recommendationImpact
                                'Customer-facing annotation' = ""
                                'Internal-facing notes'      = ($Recom.learnMoreLink.url -join " `n")
                                'Potential Benefit'          = $Recommendation.'Potential Benefit'
                                'Resource Type'              = $Resource.type
                                'Resource ID'                = $Resource.id
                            }

                        $ResourceCollection += $ResObj
                    }
                }
            }
        }
    }

    Write-Host "Gethering Resource IDs"
    $ResourceList = @()
    $ResourceIDsQuery = "resources | project id"
    foreach ($Subscription in $SubscriptionID) {
        Write-Host "ResourceID loops: $Subscription"
        try
            {
                $QueryResult = Search-AzGraph -Query $ResourceIDsQuery -first 1000 -Subscription $Subscription -Debug:$false
            }
        catch
            {
                $QueryResult = Search-AzGraph -Query $ResourceIDsQuery -first 200 -Subscription $Subscription -Debug:$false
            }

        $ResourceList += $QueryResult
        while ($QueryResult.SkipToken) {
            try
                {
                    $QueryResult = Search-AzGraph -Query $ResourceIDsQuery -SkipToken $QueryResult.SkipToken -Subscription $Subscription -first 1000 -Debug:$false
                }
            catch
                {
                    $QueryResult = Search-AzGraph -Query $ResourceIDsQuery -SkipToken $QueryResult.SkipToken -Subscription $Subscription -first 200 -Debug:$false
                }
            $ResourceList += $QueryResult
        }
    }

    Write-Host "Starting Security Data Collection for Workload: $WorkloadName"
    $MDCQuery = Get-Content -Path ("$PSScriptRoot\MDC.kql") -Raw -Encoding UTF8
    $MCSBQuery = Get-Content -Path ("$PSScriptRoot\MCSB.kql") -Raw -Encoding UTF8


    if ($SkipMDC.IsPresent) {
        Write-Host "Skipping Defender for Cloud Data Collection as per user request." -ForegroundColor Yellow
    } else {
        $MDCLocalResults = @()
        foreach ($Subscription in $SubscriptionID) {
            Write-Host "Processing Security loops: $Subscription"
            try
                {
                    $QueryResult = Search-AzGraph -Query $MDCQuery -first 1000 -Subscription $Subscription -Debug:$false
                }
            catch
                {
                    $QueryResult = Search-AzGraph -Query $MDCQuery -first 200 -Subscription $Subscription -Debug:$false
                }

            $MDCLocalResults += $QueryResult
            while ($QueryResult.SkipToken) {
                try
                    {
                        $QueryResult = Search-AzGraph -Query $MDCQuery -SkipToken $QueryResult.SkipToken -Subscription $Subscription -first 1000 -Debug:$false
                    }
                catch
                    {
                        $QueryResult = Search-AzGraph -Query $MDCQuery -SkipToken $QueryResult.SkipToken -Subscription $Subscription -first 200 -Debug:$false
                    }
                $MDCLocalResults += $QueryResult
            }
        }


        <#
        For the MDC and MCSB we are going to create the recommendation guid based in the Recommendation Title.
 
        This is logic being used:
 
        # 1) Text → UTF-8 bytes
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
 
        # 2) Bytes → HEX string
        $hex = ($bytes | ForEach-Object { $_.ToString("X2") }) -join ''
        # 48656C6C6F2C20E4B896E7958C
 
        # If you need to revert the ID back the original text, you can do the following:
 
        # 3) HEX → bytes
        $bytesBack = for ($i = 0; $i -lt $hex.Length; $i += 2) {
            [Convert]::ToByte($hex.Substring($i,2),16)
        }
 
        # 4) Bytes → original string
        $textBack = [System.Text.Encoding]::UTF8.GetString($bytesBack)
 
        #>

        Write-Host "Exporting Defender for Cloud Recommendations to CSV"
        $MDCLocalResults | Export-Csv -Path ($workingDirectory + "\DefenderForCloudRecommendations.csv") -NoTypeInformation -Encoding UTF8

        Foreach ($MDC in $MDCLocalResults) {
            if ($MDC.state -eq 'Unhealthy') {
                $MDCResourceType = $MDC.resourceId.Split('/')[6]+ '/' + $MDC.resourceId.Split('/')[7]
                $Resourceid = $ResourceList | where-object { $_.id -eq $MDC.resourceId }
                if ([string]::IsNullOrEmpty($Resourceid.id) -eq $false) {

                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($MDC.recommendationDisplayName)
                    $RecomID = ($bytes | ForEach-Object { $_.ToString("X2") }) -join ''
                    $ResObj = [PSCustomObject]@{
                                'Recommendation Guid'        = $RecomID
                                'Recommendation Title'       = $MDC.recommendationDisplayName
                                'Description'                = $MDC.description
                                'Priority'                   = $MDC.severity
                                'Customer-facing annotation' = ""
                                'Internal-facing notes'      = ("MDC Link: "+$MDC.azurePortalRecommendationLink)
                                'Potential Benefit'          = ""
                                'Resource Type'              = $MDCResourceType
                                'Resource ID'                = $Resourceid.id
                            }

                        $ResourceCollection += $ResObj
                }
            }
        }
    }

    if ($SkipMCSB.IsPresent) {
        Write-Host "Skipping Security Benchmark Data Collection as per user request." -ForegroundColor Yellow
    } else {
        $MCSBLocalResults = @()
        foreach ($Subscription in $SubscriptionID) {
            Write-Host "Processing Security loops: $Subscription"
            try
                {
                    $QueryResult = Search-AzGraph -Query $MCSBQuery -first 1000 -Subscription $Subscription -Debug:$false
                }
            catch
                {
                    $QueryResult = Search-AzGraph -Query $MCSBQuery -first 200 -Subscription $Subscription -Debug:$false
                }

            $MCSBLocalResults += $QueryResult
            while ($QueryResult.SkipToken) {
                try
                    {
                        $QueryResult = Search-AzGraph -Query $MCSBQuery -SkipToken $QueryResult.SkipToken -Subscription $Subscription -first 1000 -Debug:$false
                    }
                catch
                    {
                        $QueryResult = Search-AzGraph -Query $MCSBQuery -SkipToken $QueryResult.SkipToken -Subscription $Subscription -first 200 -Debug:$false
                    }
                $MCSBLocalResults += $QueryResult
            }
        }

        Write-Host "Exporting Security Benchmark Recommendations to CSV"
        $MCSBLocalResults | Export-Csv -Path ($workingDirectory + "\SecurityBenchmarkRecommendations.csv") -NoTypeInformation -Encoding UTF8

        Foreach ($MCSB in $MCSBLocalResults) {
            if ($MCSB.state -eq 'Unhealthy' -and $MCSB.recommendationMetadataState -eq 'failed') {
            $MCSBResourceType = $MCSB.resourceId.Split('/')[6]+ '/' + $MCSB.resourceId.Split('/')[7]
            $Resourceid = $ResourceList | where-object { $_.id -eq $MCSB.resourceId }
            if ([string]::IsNullOrEmpty($Resourceid.id) -eq $false) {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($MCSB.recommendationDisplayName)
                $RecomID = ($bytes | ForEach-Object { $_.ToString("X2") }) -join ''
                    $ResObj = [PSCustomObject]@{
                            'Recommendation Guid'        = $RecomID
                            'Recommendation Title'       = $MCSB.recommendationDisplayName
                            'Description'                = $MCSB.description
                            'Priority'                   = $MCSB.severity
                            'Customer-facing annotation' = ""
                            'Internal-facing notes'      = ("MCSB Link: "+$MCSB.azurePortalRecommendationLink)
                            'Potential Benefit'          = ""
                            'Resource Type'              = $MCSBResourceType
                            'Resource ID'                = $Resourceid.id
                        }

                    $ResourceCollection += $ResObj
                }
            }
        }
    }

    if ($SkipPSRule.IsPresent) {
        Write-Host "Skipping PSRule Data Collection as per user request." -ForegroundColor Yellow
    } else {
        Write-Host "Starting PSRule Data Collection for Workload: $WorkloadName"
        # PSRule Export
        $RuleObjects = @()
        $RuleQuery = "resources"
        foreach ($Subscription in $SubscriptionID) {
            # PSRule Resources Export
            try
                {
                    $QueryResult = Search-AzGraph -Query $RuleQuery -first 1000 -Subscription $Subscription -Debug:$false
                }
            catch
                {
                    $QueryResult = Search-AzGraph -Query $RuleQuery -first 200 -Subscription $Subscription -Debug:$false
                }

            $RuleObjects += $QueryResult
            while ($QueryResult.SkipToken) {
                try
                    {
                        $QueryResult = Search-AzGraph -Query $RuleQuery -SkipToken $QueryResult.SkipToken -Subscription $Subscription -first 1000 -Debug:$false
                    }
                catch
                    {
                        $QueryResult = Search-AzGraph -Query $RuleQuery -SkipToken $QueryResult.SkipToken -Subscription $Subscription -first 200 -Debug:$false
                    }
                $RuleObjects += $QueryResult
            }
        }

        Write-Host " - Generating CSV results..." -ForegroundColor Yellow
        $RuleObjects | Invoke-PSRule -Outcome Fail -Module PSRule.Rules.Azure -OutputPath "$workingDirectory\PSRuleResults.csv" -OutputFormat Csv
        $RulesResult = $RuleObjects | Invoke-PSRule -Outcome Fail -Module PSRule.Rules.Azure 

        foreach ($Rule in $RulesResult) {
            $ResObj = [PSCustomObject]@{
                'Recommendation Guid'        = $Rule.Ref
                'Recommendation Title'       = $Rule.Recommendation
                'Description'                = [string]$Rule.Reason
                'Priority'                   = "Medium"
                'Customer-facing annotation' = ""
                'Internal-facing notes'      = ("PSRuleID: "+$Rule.RuleId)
                'Potential Benefit'          = ""
                'Resource Type'              = $Rule.TargetType
                'Resource ID'                = $Rule.TargetObject.id
            }
            $ResourceCollection += $ResObj
        }
    }

    Write-Host "Total Recommendation Lines to Export: $($ResourceCollection.Count)"

    $ResourceCollection | Export-Csv -Path "$workingDirectory\Consolidated_Assessment_for_Review_$WorkloadName.csv" -NoTypeInformation -Encoding UTF8

    if ($ResourceCollection.Count -gt 500) {
        $Loop = $ResourceCollection.Count / 500
        $Loop = [math]::ceiling($Loop)
        $Looper = 0
        $Limit = 0
        while ($Looper -lt $Loop) {
            $Looper ++
            Write-Host "Exporting Partial CSV File: $Looper"
            $ResourceCollection[($Limit - 500)..($Limit - 1)] | Export-Csv -Path "$workingDirectory\Consolidated_Assessment_${WorkloadName}_Part${Looper}.csv" -NoTypeInformation -Encoding UTF8
            $Limit += 500
        }
    }
    else {
        Write-Host "Exporting Complete CSV File"
        $ResourceCollection | Export-Csv -Path "$workingDirectory\Consolidated_Assessment_$WorkloadName.csv" -NoTypeInformation -Encoding UTF8
    }

    if ($SkipCompress) {
        Write-Host "Skipping compression as per user request." -ForegroundColor Yellow
    } else {
        try
            {
                # Create a temporary folder to gather all contents
                $tempFolder = "$workingDirectory\TempForZip"
                New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null

                $FilesToMove = Get-ChildItem -Path $workingDirectory -Include ("WARA-File*.json",
                                                                                "Consolidated_Assessment_*.csv",
                                                                                "PSRuleResults.csv",
                                                                                "SecurityBenchmarkRecommendations.csv",
                                                                                "DefenderForCloudRecommendations.csv",
                                                                                "*Diagram*.xml",
                                                                                "*Report*.xlsx") -Recurse
                # Move all files into the temp folder
                foreach ($file in $FilesToMove) {
                    Move-Item -Path $file.FullName -Destination $tempFolder
                }

                # Compress the temp folder into a ZIP file
                Compress-Archive -Path "$tempFolder\*" -DestinationPath ($workingDirectory + "\Consolidated_Assessment" + (get-date -Format "yyyy-MM-dd_HH_mm") + ".zip") -Force
            }
        catch
            {
                Write-Host "Error during compression: " + $_.Exception.Message -ForegroundColor Red
                exit 1
            }
        # Clean up the temporary folder
        Remove-Item -Path $tempFolder -Recurse -Force

        # Output path of the created ZIP file
        $zipFilePath = Join-Path -Path $workingDirectory -ChildPath ("Consolidated_Assessment" + (get-date -Format "yyyy-MM-dd_HH_mm") + ".zip")
        Write-Host "The Assessment Data Collection ZIP file is stored at the location : $zipFilePath" -ForegroundColor Green
        # End of the script
    }

    # CleanUp
    <#
    Write-Host "Cleaning up WARA and ARI generated files..."
    if (Test-Path -PathType Leaf -Path $WARAFile) {
        Remove-Item $WARAFile -Force
    }
    #>
    if (Test-Path -PathType Container -Path "$workingDirectory\DiagramCache") {
        Remove-Item "$workingDirectory\DiagramCache" -Force -Recurse
    }
    if (Test-Path -PathType Container -Path "$workingDirectory\ReportCache") {
        Remove-Item "$workingDirectory\ReportCache" -Force -Recurse
    }
    if (Test-Path -PathType Leaf -Path "$workingDirectory\DiagramLogFile.log") {
        Remove-Item "$workingDirectory\DiagramLogFile.log" -Force
    }
}
