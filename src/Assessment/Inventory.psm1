function Invoke-Inventory {
Param($SubscriptionID)

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
    return $ResourceList
}