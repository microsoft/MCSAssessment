function Get-MCSSubscriptionList {
    param ($CSV)

    $SubscriptionIDList = @()

    foreach ($Item in $CSV)
        {
            $obj = New-Object PSObject -Property @{
                Id = $Item.'Resource ID'.split('/')[2]
            }
            $SubscriptionIDList += $obj
        }

    $SubscriptionIDList = $SubscriptionIDList | Select-Object -Property Id -Unique

    return $SubscriptionIDList
}