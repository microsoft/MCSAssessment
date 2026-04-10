function Build-MCSLowImpactSlide {
    Param($Presentation,$CustomerName,$LowRecommendation)

    $FirstSlide = 15
    $TableID = 3

    $CurrentSlide = $Presentation.Slides | Where-Object { $_.SlideIndex -eq $FirstSlide }

    $row = 2
    $Counter = 1
    $RecomNumber = 1
    foreach ($Low in $LowRecommendation) {
        $RecomName = $Low.Recommendation
        $Implication = $Low.Implication
        Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Editing Slide 12 - Adding Recommendation: ' + $RecomName)
        if ($Counter -lt 9) {
            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(1).Shape.TextFrame.TextRange.Text = [string]$RecomNumber
            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(2).Shape.TextFrame.TextRange.Text = [string]$RecomName
            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(3).Shape.TextFrame.TextRange.Text = [string]$Implication
            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(4).Shape.TextFrame.TextRange.Text = [string]$CustomerName
            $row ++
            $Counter ++
            $RecomNumber ++
        }
        else {
            Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Editing Slide 12 - Adding new Slide..')
            $Counter = 1

            $Presentation.slides[$FirstSlide].Duplicate() | Out-Null

            $FirstSlide ++

            $NextSlide = $Presentation.Slides | Where-Object { $_.SlideIndex -eq $FirstSlide }

            Start-Sleep -Seconds 1

            Write-Debug ((get-date -Format 'yyyy-MM-dd HH:mm:ss') + ' - Editing Slide 12 - Cleaning table of new slide..')
            $rowTemp = 2
            while ($rowTemp -lt 10) {
                $cell = 1
                while ($cell -lt 5) {
                    ($NextSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($rowTemp).Cells($cell).Shape.TextFrame.TextRange.Text = ''
                    $Cell ++
                }
                $rowTemp ++
            }

            $CurrentSlide = $NextSlide

            $row = 2

            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(1).Shape.TextFrame.TextRange.Text = [string]$RecomNumber
            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(2).Shape.TextFrame.TextRange.Text = [string]$RecomName
            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(3).Shape.TextFrame.TextRange.Text = [string]$Implication
            ($CurrentSlide.Shapes | Where-Object { $_.Id -eq $TableID }).Table.Rows($row).Cells(4).Shape.TextFrame.TextRange.Text = [string]$CustomerName
            $row ++
            $Counter ++
            $RecomNumber ++
        }
    }
}