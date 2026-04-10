function Connect-MCSAzureAccount {
    Param($TenantID)
    $DebugPreference = 'silentlycontinue'
    $ErrorActionPreference = 'Continue'

    Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Starting Connect-LoginSession function')
    Write-Host $AzureEnvironment -BackgroundColor Green
    $Context = Get-AzContext -ErrorAction SilentlyContinue

        Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Tenant ID was informed.')

        if($Context.Tenant.Id -ne $TenantID)
        {
            Set-AzContext -Tenant $TenantID -ErrorAction SilentlyContinue | Out-Null
            $Context = Get-AzContext -ErrorAction SilentlyContinue
        }
        $Subs = Get-AzSubscription -TenantId $TenantID -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

        if([string]::IsNullOrEmpty($Subs))
            {
                try 
                    {
                        Write-Debug ((get-date -Format 'yyyy-MM-dd_HH_mm_ss')+' - '+'Editing Login Experience')
                        $AZConfig = Get-AzConfig -LoginExperienceV2 -WarningAction SilentlyContinue -InformationAction SilentlyContinue
                        if ($AZConfig.value -eq 'On')
                            {
                                Update-AzConfig -LoginExperienceV2 Off | Out-Null
                                Update-AzConfig -EnableLoginByWam 0 | Out-Null
                                Connect-AzAccount -Tenant $TenantID -Environment $AzureEnvironment | Out-Null
                                Update-AzConfig -LoginExperienceV2 On | Out-Null
                                Update-AzConfig -EnableLoginByWam 1 | Out-Null
                            }
                        else
                            {
                                Connect-AzAccount -Tenant $TenantID -Environment $AzureEnvironment | Out-Null
                            }
                    }
                catch
                    {
                        Connect-AzAccount -Tenant $TenantID -Environment $AzureEnvironment | Out-Null
                    }
            }
        else
            {
                Write-Host "Already authenticated in Tenant $TenantID"
            }
        }