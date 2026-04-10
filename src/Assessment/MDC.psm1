function Invoke-MCSMDC {
    Param($SubscriptionID,$MDCQuery,$ResourceList,$WorkingDirectory
    )

    $MDCLocalResults = @()
    $ResourceCollection = @()
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
    return $ResourceCollection
}