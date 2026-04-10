<#
.SYNOPSIS
    Consolidated assessment script for Azure workloads, leveraging multiple tools to gather security and optimization recommendations.

.DESCRIPTION
    This script runs all the necessary tools to compose the assessment of a workload in Azure, including Azure Resource Inventory, WARA, Defender for Cloud, Security Benchmark and PSRule. The output is a table in CSV format that can be easily analyzed and shared.

.PARAMETER TenantID
    Specify the tenant ID of the workload.

.PARAMETER SubscriptionID
    Use this parameter to specify Subscription in the Tenant

.PARAMETER WorkloadName
    Use this parameter to specify the name of the workload. This will be used as suffix for the generated files.

.PARAMETER SkipCompress
    Use this parameter to skip the final compression of the generated files in a ZIP file.

.PARAMETER SkipARI
    Use this parameter to skip the Azure Resource Inventory collection.

.PARAMETER SkipWARA
    Use this parameter to skip the WARA recommendations collection.

.PARAMETER SkipMDC
    Use this parameter to skip the MDC collection.

.PARAMETER SkipMCSB
    Use this parameter to skip the MCSB collection.

.PARAMETER SkipPSRule
    Use this parameter to skip the PSRule collection.

.PARAMETER FullWARA
    By default, only the WARA recommendations with automated remediation are included in the output. Use this parameter to include all the WARA recommendations, even those without automated remediation (non-automated ones will have "N/A" in the "Potential Benefit" column of the output).

.EXAMPLE
    Default utilization. Specify tenant and Subscriptions that are part of the workload:
    PS C:\> Invoke-MCSAssessment -TenantID "00000000-0000-0000-0000-000000000000" -SubscriptionID 00000000-0000-0000-0000-000000000000,11111111-1111-1111-1111-111111111111 -WorkloadName "XYZ - Prod"

    Runs the script but skips Azure Resource Inventory collection:
    PS C:\> Invoke-MCSAssessment -TenantID "00000000-0000-0000-0000-000000000000" -SubscriptionID 00000000-0000-0000-0000-000000000000,11111111-1111-1111-1111-111111111111 -SkipARI -WorkloadName "XYZ - Prod"

    Runs the script and include all WARA recommendations (not only the automated ones):
    PS C:\> Invoke-MCSAssessment -TenantID "00000000-0000-0000-0000-000000000000" -SubscriptionID 00000000-0000-0000-0000-000000000000,11111111-1111-1111-1111-111111111111 -FullWARA -WorkloadName "XYZ - Prod"

.NOTES
    AUTHORS: Claudio Merola | Azure Infrastucture/Automation/Devops/Governance

    Copyright (c) 2025 Microsoft Corporation. All rights reserved.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.

.LINK
    Official Repository: TBD
#>
function Invoke-MCSAssessment {
    Param(
    [Alias("Tenant","Tenants")]
    [string]$TenantID,
    [Alias("Subscription","Subscriptions","Subs")]
    [String[]]$SubscriptionID,
    [Alias("Workload","Workloads")]
    [String]$WorkloadName = "Default_Workload",
    [switch]$SkipCompress,
    [switch]$SkipARI,
    [switch]$SkipWARA,
    [switch]$SkipMDC,
    [switch]$SkipMCSB,
    [switch]$SkipPSRule,
    [switch]$FullWARA
    )   

    Write-Host "Setting Variables.."
    $workingDirectory = (Get-Location).Path
    Write-Host "Working Directory: $workingDirectory"
    if ($workingDirectory -eq "C:\") {
        Write-Host "Error: Working Directory cannot be the root of C:\" -ForegroundColor Red
        exit 1
    }

    Write-Host "Validating Parameters..."
    if (-Not $TenantID) {
        Write-Host "Error: No TenantID" -ForegroundColor Red
        exit 1
    }

    if (-Not $SubscriptionID) {
        Write-Host "Error: No SubscriptionID" -ForegroundColor Red
        exit 1
    }

    if ($SkipARI.IsPresent) {
        Write-Host "Skipping ARI Data Collection as per user request." -ForegroundColor Yellow
    } else {
        Write-Host "Starting ARI Data Collection for Workload: $WorkloadName"
        Invoke-ARI -ReportDir $workingDirectory -ReportName $WorkloadName -NoAutoUpdate -DiagramFullEnvironment -TenantId $TenantID -SubscriptionId $SubscriptionID -Debug -IncludeCosts -Lite
    }

    $ResourceCollection = @()

    if ($SkipWARA.IsPresent) {
        Write-Host "Skipping WARA Data Collection as per user request." -ForegroundColor Yellow
    } else {
        $ResourceCollection += Invoke-MCSWARA -TenantID $TenantID -SubscriptionID $SubscriptionID -WorkloadName $WorkloadName -FullWARA $FullWARA -WorkingDirectory $workingDirectory
    }

    $ResourceList = Invoke-Inventory -SubscriptionID $SubscriptionID

    Write-Host "Starting Security Data Collection for Workload: $WorkloadName"

        <#
        For the MDC and MCSB we are going to create the recommendation guid based in the Recommendation Title.

        This is logic being used:

        # 1) Text → UTF-8 bytes
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)

        # 2) Bytes → HEX string
        $hex = ($bytes | ForEach-Object { $_.ToString("X2") }) -join ''
        # 48656C6C6F2C20E4B896E7958C

        # If you need to revert the ID back the original text, you can do the following:

        # 3) HEX → bytes
        $bytesBack = for ($i = 0; $i -lt $hex.Length; $i += 2) {
            [Convert]::ToByte($hex.Substring($i,2),16)
        }

        # 4) Bytes → original string
        $textBack = [System.Text.Encoding]::UTF8.GetString($bytesBack)

        #>

    $MDCQuery = Get-Content -Path ("$PSScriptRoot\MDC.kql") -Raw -Encoding UTF8
    $MCSBQuery = Get-Content -Path ("$PSScriptRoot\MCSB.kql") -Raw -Encoding UTF8

    if ($SkipMDC.IsPresent) {
        Write-Host "Skipping Defender for Cloud Data Collection as per user request." -ForegroundColor Yellow
    } else {
        $ResourceCollection += Invoke-MCSMDC -SubscriptionID $SubscriptionID -MDCQuery $MDCQuery -ResourceList $ResourceList -WorkingDirectory $workingDirectory
        }

    if ($SkipMCSB.IsPresent) {
        Write-Host "Skipping Security Benchmark Data Collection as per user request." -ForegroundColor Yellow
    } else {
        $ResourceCollection += Invoke-MCSMCSB -SubscriptionID $SubscriptionID -MCSBQuery $MCSBQuery -ResourceList $ResourceList -WorkingDirectory $workingDirectory
    }

    if ($SkipPSRule.IsPresent) {
        Write-Host "Skipping PSRule Data Collection as per user request." -ForegroundColor Yellow
    } else {
        $ResourceCollection += Invoke-MCSPSRule -SubscriptionID $SubscriptionID -WorkingDirectory $workingDirectory
    }

    Write-Host "Total Recommendation Lines to Export: $($ResourceCollection.Count)"

    $ResourceCollection | Export-Csv -Path "$workingDirectory\Consolidated_Assessment_for_Review_$WorkloadName.csv" -NoTypeInformation -Encoding UTF8

    if ($SkipCompress.IsPresent) {
        Write-Host "Skipping compression as per user request." -ForegroundColor Yellow
    } else {
        Invoke-MCSCompress -WorkingDirectory $WorkingDirectory
    }

    Remove-MCSFiles -WorkingDirectory $workingDirectory
}

function New-MCSAssessmentReport {
    Param(
        [Alias("Tenant","Tenants")]
        [string]$TenantID,
        [Alias("Workload","Workloads")]
        [String]$WorkloadName,
        [string]$CustomerName,
        [string]$CsvFile,
        [string]$FoundryEndpoint,
        [string]$ExtraRequest
    )

    Write-Host "Validating Parameters..."
    if (-Not $TenantID) {
        Write-Host "Error: No TenantID" -ForegroundColor Red
        exit 1
    }

    if (-Not $WorkloadName) {
        Write-Host "Error: No WorkloadName" -ForegroundColor Red
        exit 1
    }

    if (-Not $CustomerName) {
        Write-Host "Error: No CustomerName" -ForegroundColor Red
        exit 1
    }

    if (-Not $CsvFile) {
        Write-Host "Error: No CsvFile" -ForegroundColor Red
        exit 1
    }

    $PPTTemplateFile = Get-MCSTemplatePPT

    Connect-MCSAzureAccount -TenantID $TenantID

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Connected to Azure Account')

    $workingFolderPath = Get-Location
    $workingFolderPath = $workingFolderPath.Path
    $NewPPTFile = ($workingFolderPath + '\Consolidated Assessment - ' + $CustomerName + ' - ' + (get-date -Format "yyyy-MM-dd-HH-mm") + '.pptx')

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Openning CSV File')

    $CSV = Import-Csv -Path $CSVFile

    $ResourceTypes = $Csv.'Resource Type' | Select-Object -Unique -CaseInsensitive

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Extracting Subscriptions from CSV')

    $Subscriptions = Get-MCSSubscriptionList -CSV $CSV

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Checking Foundry Endpoint')
    if($FoundryEndpoint)
        {
            $MetroAgent = Get-MCSMetroAIAgent -FoundryEndpoint $FoundryEndpoint

            $MetroAgentName = $MetroAgent.Name

            Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Foundry Agent to be used: '+ $MetroAgentName)

            Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Creating Conversation')

            $Conversation = New-MetroAIConversation -Debug:$false

            Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Getting Implications')

            $Recommendations = Get-MCSMetroAIAnswers -Csv $CSV -MetroAgent $MetroAgent -ExtraRequest $ExtraRequest -Conversation $Conversation
        }
    else
        {
            Foreach ($Recommendation in $CSV)
            {
                $Answer = @{
                    "Recommendation" = $Recommendation.'Recommendation Title'
                    "Priority" = $Recommendation.Priority
                    "Implication" = "N/A"
                }

                $Recommendations += $Answer
            }
        }

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Processing Recommendations')

    $LowRecommendation = $Recommendations | where-object {$_.Priority -eq "Low"} | Select-Object -Property "Recommendation","Implication" -Unique
    $MediumRecommendation = $Recommendations | where-object {$_.Priority -eq "Medium"} | Select-Object -Property "Recommendation","Implication" -Unique
    $HighRecommendation = $Recommendations | where-object {$_.Priority -eq "High"} | Select-Object -Property "Recommendation","Implication" -Unique

    $Application = New-Object -ComObject PowerPoint.Application
    $Presentation = $Application.Presentations.Open($PPTTemplateFile, $null, $null, $null)

    Build-MCSSlide1 -Presentation $Presentation -CustomerName $CustomerName -WorkLoadName $WorkloadName

    Build-MCSSlide6 -Presentation $Presentation -CustomerName $CustomerName

    Build-MCSSlide7 -Presentation $Presentation -CustomerName $CustomerName -WorkLoadName $WorkloadName -ResourceTypes $ResourceTypes -Subscriptions $Subscriptions

    Build-MCSLowImpactSlide -Presentation $Presentation -CustomerName $CustomerName -LowRecommendation $LowRecommendation

    Build-MCSMediumImpactSlide -Presentation $Presentation -CustomerName $CustomerName -MediumRecommendation $MediumRecommendation

    Build-MCSHighImpactSlide -Presentation $Presentation -CustomerName $CustomerName -HighRecommendation $HighRecommendation

    $Presentation.SaveAs($NewPPTFile)
    $Presentation.Close()
    $Application.Quit()

    Write-Host ''
    Write-Host ('Presentation file saved at: ') -NoNewline
    write-host $NewPPTFile -ForegroundColor Cyan
    Write-Host ''
}