class BackupAgent {
    $parameters = $null

    $vmRepositery = $null
    $snapshotRepositery = $null
    $diskRepositery = $null
    $backupRepositery = $null

    BackupAgent($appParam) {
        if (-not($appParam)) {
            Write-Error "BackupAgent Instance should have a valid parameters" -ErrorAction Stop
        }
        $this.parameters = $appParam

        $this.vmRepositery = [VmRepositery]::new($this.parameters)  
        $this.snapshotRepositery = [SnapshotRepositery]::new($this.parameters)
        $this.diskRepositery = [DiskRepositery]::new($this.parameters)
        $this.backupRepositery =  [BackupRepositery]::new($this.parameters)
    }   
}