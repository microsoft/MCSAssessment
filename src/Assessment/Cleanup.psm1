function Remove-MCSFiles {
    Param($WorkingDirectory)

    # CleanUp
    <#
    Write-Host "Cleaning up WARA and ARI generated files..."
    if (Test-Path -PathType Leaf -Path $WARAFile) {
        Remove-Item $WARAFile -Force
    }
    #>
    if (Test-Path -PathType Container -Path "$workingDirectory\DiagramCache") {
        Remove-Item "$workingDirectory\DiagramCache" -Force -Recurse
    }
    if (Test-Path -PathType Container -Path "$workingDirectory\ReportCache") {
        Remove-Item "$workingDirectory\ReportCache" -Force -Recurse
    }
    if (Test-Path -PathType Leaf -Path "$workingDirectory\DiagramLogFile.log") {
        Remove-Item "$workingDirectory\DiagramLogFile.log" -Force
    }
}