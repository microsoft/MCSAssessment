function Build-MCSSlide6 {
    Param(
        [Parameter(Mandatory = $true)]
        [object]$Presentation,
        [Parameter(Mandatory = $true)]
        [string]$CustomerName
    )

    $SlideWorkloadSummary = $Presentation.Slides | Where-Object { $_.SlideIndex -eq 6 }

    $TargetShape = ($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 23 })
    $TargetShape.TextFrame.TextRange.Text = "$CustomerName Stakeholders"

    $TargetShape = ($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 8 })
    $TargetShape.TextFrame.TextRange.Text = "$CustomerName Application Leads"

    $TargetShape = ($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 9 })
    $TargetShape.TextFrame.TextRange.Text = "$CustomerName Application Product Team/Engineer"

    $TargetShape = ($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 2058 })
    $TargetShape.TextFrame.TextRange.Text = "$CustomerName Team"

    $TargetShape = ($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 31 })
    $TargetShape.TextFrame.TextRange.Text = "$CustomerName Architect"
}