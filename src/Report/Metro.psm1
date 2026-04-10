function Get-MCSMetroAIAgent {
    Param($FoundryEndpoint)

    Set-MetroAIContext -Endpoint $FoundryEndpoint -ApiType Agent -Debug:$false

    #$agent = Get-MetroAIAgent | Where-Object {$_.Name -eq 'MCSAgent'}

    $MetroAgent = Get-MetroAIAgent -Debug:$false

    return $MetroAgent

}

function Get-MCSMetroAIAnswers {
    Param(
        $CSV,
        $MetroAgent,
        $Conversation,
        $ExtraRequest
    )

    $Recommendations = $CSV | Select-Object -Property "Recommendation Title","Description","Priority" -Unique

    $AIRecommendations = @()

    Foreach ($Recommendation in $Recommendations)
    {
        Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+"Getting AI explanation for: $($Recommendation.'Recommendation Title')")
        if ($ExtraRequest)
        {
            $Prompt = "Based on the PSRule (https://github.com/Azure/PSRule.Rules.Azure/tree/main/docs/en/rules), APRL and Microsoft Defender for Cloud recommendations, I received the following recommendation: '$($Recommendation.Recommendation)', with the following deeper description: '$($Recommendation.Description)'. Can you explain in less than 80 words what are the implications for my Azure environment if I don't follow that recommendation? and also $ExtraRequest"
        }
        else
        {
            $Prompt = "Based on the PSRule (https://github.com/Azure/PSRule.Rules.Azure/tree/main/docs/en/rules), APRL and Microsoft Defender for Cloud recommendations, I received the following recommendation: '$($Recommendation.Recommendation)', with the following deeper description: '$($Recommendation.Description)'. Can you explain in less than 80 words what are the implications for my Azure environment if I don't follow that recommendation?"
        }
        $turn  = Invoke-MetroAIConversation -AgentId $MetroAgent.id -ConversationId $Conversation.id -UserInput $Prompt -Debug:$false
        Start-Sleep -Seconds 1
        Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+"Received AI explanation: $($turn.AssistantText)")

        $Answer = @{
            "Recommendation" = $Recommendation.'Recommendation Title'
            "Priority" = $Recommendation.Priority
            "Implication" = $turn.AssistantText
        }

        $AIRecommendations += $Answer
    }

    return $AIRecommendations
}