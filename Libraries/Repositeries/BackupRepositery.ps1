class BackupRepositery {
    $parameters = $null
    $vmRepositery = $null
    $snapshotRepositery = $null
    $vms = $null
    $snapshots = $null

    BackupRepositery($appParam) {
        if (-not($appParam)) {
            Write-Error "BackupRepositery Instance should have a valid parameters" -ErrorAction Stop
        }
        $this.parameters = $appParam
        $this.vmRepositery = [VmRepositery]::new($this.parameters)  
        $this.snapshotRepositery = [SnapshotRepositery]::new($this.parameters)
    
        $this.vms = $this.vmRepositery.GetAzVms()
        $this.snapshots = $this.snapshotRepositery.GetAzSnapshots()
    }

    [Backup[]] FindAll() {
        [Backup[]] $results = @()

        $backupFiles = Get-ChildItem "$($this.parameters.backupManifestPath)" -Filter *.json

        foreach ($backupFile in $backupFiles) {
            $result = $this.Find($backupFile.BaseName)

            if ($result) { $results += $result }
        }

        return $results
    }

    [Backup] Find($backupId) {
        [Backup]$backup = $null

        $backupFilePath = "$($this.parameters.backupManifestPath)\$($backupId).json"

        if (-not(Test-Path $backupFilePath)) { return $null }

        try {
            $backupManifest = Get-Content $backupFilePath | ConvertFrom-Json
            $backupState = [BackupState]::Online

            if ($backupManifest) {
                $bkpServers = @()

                foreach ($server in $backupManifest.Servers) {
                    $bkpSnapShots = @()

                    $serverState = [BackupState]::Online
                    $existingVm = $this.vms | Where-Object { $_.Name -eq $server.Name }

                    if (-not($existingVm)) {
                        $backupState = [BackupState]::Offline
                        $serverState = [BackupState]::Offline
                    }

                    foreach ($snapShot in $server.Snapshots) {
                        $snapShotState = [BackupState]::Online
                        
                        $existingSnapShot = $this.snapshots | Where-Object { $_.Name -eq $snapShot.FileName }

                        if (-not($existingSnapShot)) {
                            $backupState = [BackupState]::Offline
                            $snapShotState = [BackupState]::Offline
                        }

                        $bkpSnapShots += [Snapshot]::new($snapShot.FileName, $snapShotState, $snapShot.DiskId, $snapShot.DiskName, $snapShot.DiskSkuName, $snapShot.DiskType, $snapShot.DiskLun) 
                    }

                    $bkpServers += [Server]::new($server.Name, $serverState, $bkpSnapShots)
                }

                $backup = [Backup]::new($backupID, $backupManifest.Description, $backupManifest.Created, $backupState, $bkpServers)
            }

            return $backup
        }
        catch {
            return $null
        }
    }

    [Void] Create([Backup]$backup) {        
        $backup | ConvertTo-Json -Depth 10 | Out-File "$($this.parameters.backupManifestPath)\$($backup.ID).json"
    }

    [Void] Remove([Backup]$backup) {
        $jobs = @()

        foreach ($server in $backup.Servers) {
            Write-Host "{'$($backup.ID)', '$($server.Name)'}' : Removing ..." -ForegroundColor Cyan

            Write-Host "{'$($backup.ID)', '$($server.Name)'} : Deleting snapshot ..." -ForegroundColor Green
            foreach ($snapShot in $server.Snapshots) {
                $existingSnapShot = $this.snapshots | Where-Object { $_.Name -eq $snapShot.FileName }
                if ($existingSnapShot) {
                    Write-Host "$($snapShot.FileName)"
                    $jobs += Remove-AzSnapshot -ResourceGroupName $($this.parameters.snapshotResourceGroupName) -SnapshotName $snapShot.FileName -Force -AsJob
                }
            }
        }

        $jobs | Wait-Job
        $jobs| Receive-Job

        $jobs | Remove-Job -Force
        
        Remove-Item "$($this.parameters.backupManifestPath)\$($backup.ID).json"        
        Write-Host "{'$($backup.ID)'}' : Removed" -ForegroundColor Cyan
    }
}