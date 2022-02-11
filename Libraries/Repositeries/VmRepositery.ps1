class VmRepositery {
    $parameters = $null

    VmRepositery($appParam) {
        if (-not($appParam)) {
            Write-Error "VmRepositery Instance should have a valid parameters" -ErrorAction Stop
        }
        $this.parameters = $appParam
    }

    [Object] GetAzVms() {
        return Get-AzVM -ResourceGroupName $($this.parameters.vmResourceGroupName) -Status
    }

    [Object] GetAzVm($vmName) {
        $vm = $null
        $vms = $this.GetAzVms()
        
        if ($vms) {
            $vm = $vms | Where-Object { $_.Name -eq $vmName }
        }

        if (-not($vm)) {
            return $null
        }
        else {
            return $vm
        }
    }

    [Bool] IsVmRunningState($vmName) {
        $vmInstance = $this.GetAzVm($vmName)

        if (-not($vmInstance)) {
            Write-Error "VM '$($vmName)' is not available" -ErrorAction Stop
        }

        return ([string]::Compare($vmInstance.PowerState, "VM running", $true) -eq 0)
    }

    [Object] StopVmAsJob($vmName) {
        $vmInstance = $this.GetAzVm($vmName)

        if (-not($vmInstance)) {
            Write-Error "VM '$($vmName)' is not available" -ErrorAction Stop
        }

        if ([string]::Compare($vmInstance.PowerState, "VM running", $true) -eq 0) {
            Write-Host "{'$($vmInstance.Name)'}' : Stopping VM ..." -ForegroundColor Green
            return Stop-AzVM -ResourceGroupName $vmInstance.ResourceGroupName -Name $vmInstance.Name -Force -AsJob
        }

        return $null
    }

    [Void] StartVmAsJob($vmName) {
        $vmInstance = $this.GetAzVm($vmName)

        if (-not($vmInstance)) {
            Write-Error "VM '$($vmName)' is not available" -ErrorAction Stop
        }

        if ([string]::Compare($vmInstance.PowerState, "VM running", $true) -ne 0) {
            Write-Host "{'$($vmInstance.Name)'}' : Starting VM ..." -ForegroundColor Green
            Start-AzVM -ResourceGroupName $vmInstance.ResourceGroupName -Name $vmInstance.Name -AsJob
        }
    }

    [Object] StopVm($vmName) {
        $vmInstance = $this.GetAzVm($vmName)

        if (-not($vmInstance)) {
            Write-Error "VM '$($vmName)' is not available" -ErrorAction Stop
        }

        if ([string]::Compare($vmInstance.PowerState, "VM running", $true) -eq 0) {
            Write-Host "{'$($vmInstance.Name)'}' : Stopping VM ..." -ForegroundColor Green
            return Stop-AzVM -ResourceGroupName $vmInstance.ResourceGroupName -Name $vmInstance.Name -Force
        }

        return $null
    }

    [Void] StartVm($vmName) {
        $vmInstance = $this.GetAzVm($vmName)

        if (-not($vmInstance)) {
            Write-Error "VM '$($vmName)' is not available" -ErrorAction Stop
        }

        if ([string]::Compare($vmInstance.PowerState, "VM running", $true) -ne 0) {
            Write-Host "{'$($vmInstance.Name)'}' : Starting VM ..." -ForegroundColor Green
            Start-AzVM -ResourceGroupName $vmInstance.ResourceGroupName -Name $vmInstance.Name
        }
    }

    [Void] RemoveAzVmDataDisk($vmInstance, [object]$diskNames) {
        if ($diskNames) {
            foreach ($diskName in $diskNames) {
                Write-Host $diskName
                Remove-AzVMDataDisk -VM $vmInstance -Name $($diskName) -Confirm:$false
            }
        }
    }
}