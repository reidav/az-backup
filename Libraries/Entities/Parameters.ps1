class Parameters {
    $azRootPath = $null
    $backupManifestPath = $null
    $tenantSubscriptionId = $null
    
    $snapshotResourceGroupName = $null
    $snapshotStorageType = $null

    $vmResourceGroupName = $null
    $vmSwapDiskSuffix = "_MD_TEMP_SWAP"

    Parameters([string] $azRootPath) {
        # Global variables
        $this.azRootPath = $azRootPath
        $this.backupManifestPath = "$($azRootPath)\Backups"
        $configFilePath = "$($azRootPath)\config.json"

        if (-not(Test-Path $configFilePath)) {
            $msg = "Unable to find configuration file at $($configFilePath)."
            Write-Warning $msg
            throw $msg
        }

        $config = Get-Content $configFilePath -Raw | ConvertFrom-Json

        $this.tenantSubscriptionId = $config.SubscriptionId

        $this.snapshotResourceGroupName = $config.Snapshots.ResourceGroupName
        $this.snapshotStorageType = $config.Snapshots.StorageType

        $this.vmResourceGroupName = $config.Vms.ResourceGroupName
    }
}