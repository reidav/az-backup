class SnapshotRepositery {
    $parameters = $null

    SnapshotRepositery($appParam) {
        if (-not($appParam)) {
            Write-Error "SnapshotRepositery Instance should have a valid parameters" -ErrorAction Stop
        }
        $this.parameters = $appParam
    }

    [Object] GetAzSnapshots() {
        return Get-AzSnapshot -ResourceGroupName $($this.parameters.snapshotResourceGroupName)
    }

    [Object] GetAzSnapshot($snapshotName) {
        $snapshot = $null
        $snapshots = $this.GetAzSnapshots()
        
        if ($snapshots) {
            $snapshot = $snapshots | Where-Object { $_.Name -eq $snapshotName }
        }

        if (-not($snapshot)) {
            return $null
        }
        else {
            return $snapshot
        }        
    }

    [Object] CreateSnapshotAsJob($vmInstanceLocation, $sourceDiskId, $snapShotName) {
        $snapshotConfig = New-AzSnapshotConfig -AccountType $($this.parameters.snapshotStorageType) -Location $vmInstanceLocation -CreateOption Copy -SourceUri $sourceDiskId 
        return New-AzSnapshot -Snapshot $snapshotConfig -ResourceGroupName $($this.parameters.snapshotResourceGroupName) -SnapshotName $snapShotName -AsJob
    }

    [Object] RemoveSnapshotAsJob([string]$snapshotFilename) {
        $job = $null
        if ($snapshotFilename) {
            Write-Host "$($snapshotFilename)"
            $job = Remove-AzSnapshot -ResourceGroupName $($this.parameters.snapshotResourceGroupName) -SnapshotName $snapshotFilename -Force -AsJob
        }
        return $job
    }
}