function Invoke-MCSPSRule {
    Param($SubscriptionID,$WorkingDirectory)

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

    Write-Host "  - Generating CSV results..." -ForegroundColor Yellow
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
    return $ResourceCollection
}