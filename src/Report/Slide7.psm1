function Build-MCSSlide7 {
    Param($Presentation,$CustomerName,$WorkLoadName,$ResourceTypes,$Subscriptions)

    $SlideWorkloadSummary = $Presentation.Slides | Where-Object { $_.SlideIndex -eq 7 }
    $TargetShape = ($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 6 })
    $TargetShape.TextFrame.TextRange.Text = "$CustomerName - $WorkLoadName"

    $TargetShape = ($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 26 })
    $TargetShape.TextFrame.TextRange.Text = "The following services and subscriptions have been identified as a part of the $CustomerName - $WorkLoadName and will receive the elevated experience"

    $ResourceTypes = $ResourceTypes | Select-Object -First 15

    $loop = 1
    foreach ($ResourcesType in $ResourceTypes) {
        $LogResName = $ResourcesType
        Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Editing Slide 7 - Adding Resource Type: ' + $LogResName)
        if ($loop -eq 1) {
            ($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 2 }).Table.Rows(1).Cells(1).Shape.TextFrame.TextRange.Text = [string]$ResourcesType
            ($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 2 }).Table.Rows(1).Height = 20
        }
        else {
            ($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 2 }).Table.Rows.Add() | Out-Null
            ($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 2 }).Table.Rows($loop).Cells(1).Shape.TextFrame.TextRange.Text = [string]$ResourcesType
            ($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 2 }).Table.Rows($loop).Height = 20
        }
        $loop ++
    }

    $loop = 2
    foreach ($Subscription in $Subscriptions) {
        $SubName = $Subscription.Name
        Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Editing Slide 7 - Adding Subscription: ' + $SubName)
        if ($loop -eq 1) {
            #($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 30 }).Table.Rows(2).Cells(1).Shape.TextFrame.TextRange.Text = [string]$SubName
            ($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 30 }).Table.Rows(2).Cells(2).Shape.TextFrame.TextRange.Text = [string]$Subscription.Id
        }
        else {
            #($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 2 }).Table.Rows.Add() | Out-Null
            #($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 30 }).Table.Rows($loop).Cells(1).Shape.TextFrame.TextRange.Text = [string]$SubName
            ($SlideWorkloadSummary.Shapes | Where-Object { $_.Id -eq 30 }).Table.Rows($loop).Cells(2).Shape.TextFrame.TextRange.Text = [string]$Subscription.Id
        }
        $loop ++
    }
}