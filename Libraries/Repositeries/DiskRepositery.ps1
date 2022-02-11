class DiskRepositery {
    $parameters = $null

    DiskRepositery($appParam) {
        if (-not($appParam)) {
            Write-Error "DiskRepositery Instance should have a valid parameters" -ErrorAction Stop
        }
        $this.parameters = $appParam
    }

    [Object] GetAzDisks() {
        return  Get-AzDisk -ResourceGroupName $($this.parameters.vmResourceGroupName)
    }

    [Object] GetAzSnapshotsDisks() {
        return Get-AzDisk -ResourceGroupName $($this.parameters.snapshotResourceGroupName)
    }

    [Object] GetVmOsSwapDisk($vmInstance) {
        # Check if this VM already contains a Swap OS disk, if not we create it
        $tempSwapDiskName = "$($vmInstance.Name)$($this.parameters.vmSwapDiskSuffix)"
        $tempSwapDisk = $this.GetAzSnapshotsDisks() | Where-Object { $_.Name -eq $tempSwapDiskName }       

        if (-not($tempSwapDisk)) {    
            Write-Host "$($vmInstance.Name) : creating $tempSwapDiskName ..."        
            $osDisk = $vmInstance.StorageProfile.OsDisk
            $osExistingDisk = $this.GetAzDisks() | Where-Object { $_.Name -eq $osDisk.Name } 
            if (-not($osExistingDisk)) {
                Write-Error "Failed to create temp swap disk. '$($osDisk.Name)' does not exists." -ErrorAction Stop
            }

            $diskConfig = New-AzDiskConfig -SourceResourceId $osExistingDisk.Id -Location $osExistingDisk.Location -CreateOption Copy 
            New-AzDisk -Disk $diskConfig -DiskName $tempSwapDiskName -ResourceGroupName $this.parameters.snapshotResourceGroupName
            $tempSwapDisk = $this.GetAzSnapshotsDisks() | Where-Object { $_.Name -eq $tempSwapDiskName }
        }

        return $tempSwapDisk
    }

    [Object] RemoveAzDiskAsJob([object]$diskNames) {
        $jobs = @()
        if ($diskNames) {
            for ($i = 0; $i -lt $diskNames.Length; $i++) {
                $diskName = $diskNames[$i]
                Write-Host $diskName
                $jobs += Remove-AzDisk -ResourceGroupName $($this.parameters.vmResourceGroupName) -DiskName $diskName -Force -AsJob
            }
        }
        return $jobs
    }
}