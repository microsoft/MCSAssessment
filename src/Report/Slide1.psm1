function Build-MCSSlide1 {
    Param($Presentation,$CustomerName,$WorkLoadName)

    $SlideWorkloadSummary = $Presentation.Slides | Where-Object { $_.SlideIndex -eq 1 }
    $TargetShape = ($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 5 })
    $TargetShape.TextFrame.TextRange.Text = "$CustomerName - $WorkLoadName"
}