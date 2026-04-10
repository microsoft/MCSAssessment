function Invoke-MCSCompress {
    Param($WorkingDirectory)

    try
        {
            # Create a temporary folder to gather all contents
            $tempFolder = "$workingDirectory\TempForZip"
            New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null

            $FilesToMove = Get-ChildItem -Path $workingDirectory -Include ("WARA-File*.json",
                                                                            "Consolidated_Assessment_*.csv",
                                                                            "PSRuleResults.csv",
                                                                            "SecurityBenchmarkRecommendations.csv",
                                                                            "DefenderForCloudRecommendations.csv",
                                                                            "*Diagram*.xml",
                                                                            "*Report*.xlsx") -Recurse
            # Move all files into the temp folder
            foreach ($file in $FilesToMove) {
                Move-Item -Path $file.FullName -Destination $tempFolder
            }

            # Compress the temp folder into a ZIP file
            Compress-Archive -Path "$tempFolder\*" -DestinationPath ($workingDirectory + "\Consolidated_Assessment" + (get-date -Format "yyyy-MM-dd_HH_mm") + ".zip") -Force
        }
    catch
        {
            Write-Host "Error during compression: " + $_.Exception.Message -ForegroundColor Red
            exit 1
        }
    # Clean up the temporary folder
    Remove-Item -Path $tempFolder -Recurse -Force

    # Output path of the created ZIP file
    $zipFilePath = Join-Path -Path $workingDirectory -ChildPath ("Consolidated_Assessment" + (get-date -Format "yyyy-MM-dd_HH_mm") + ".zip")
    Write-Host "The Assessment Data Collection ZIP file is stored at the location : $zipFilePath" -ForegroundColor Green
    # End of the script
}