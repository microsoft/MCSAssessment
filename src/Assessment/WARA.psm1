function Invoke-MCSWARA {
    Param(
        [string]$TenantID,
        [string[]]$SubscriptionID,
        [string]$WorkloadName,
        [switch]$FullWARA,
        [string]$workingDirectory
    )

    # WARA Files
    $RecommendationResourceTypesUri = 'https://azure.github.io/WARA-Build/objects/WARAinScopeResTypes.csv'
    $RecommendationDataUri = 'https://azure.github.io/WARA-Build/objects/recommendations.json'

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

    return $ResourceCollection
}