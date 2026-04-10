function Invoke-MCSMCSB {
    Param($SubscriptionID,$MCSBQuery,$ResourceList,$WorkingDirectory)

    $MCSBLocalResults = @()
    $ResourceCollection = @()
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
    return $ResourceCollection
}