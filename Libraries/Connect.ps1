class Connect {
    
    $parameters = $null

    Connect($appParam) {
        if (-not($appParam)) {
            Write-Error "VmRepositery Instance should have a valid parameters" -ErrorAction Stop
        }
        $this.parameters = $appParam

        $needLogin = $true

        Try {
            $content = Get-AzContext
            
            if ($content) {
                $needLogin = ([string]::IsNullOrEmpty($content.Account))

                if ($content.Subscription.Id -ne $($this.parameters.tenantSubscriptionId)) {
                    $content = Set-AzContext -SubscriptionId $($this.parameters.tenantSubscriptionId)
                }
            }
        }
        catch {
            if ($_ -like "*Connect-AzAccount to login*") {
                $needLogin = $true
            }
            else {
                throw
            }
        }

        if ($needLogin) {
            Connect-AzAccount
            Enable-AzContextAutosave -Scope CurrentUser
        }
    }
 }