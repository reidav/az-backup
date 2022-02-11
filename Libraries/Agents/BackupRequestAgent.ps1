class BackupRequestAgent : BackupAgent {

    BackupRequestAgent($ctxParam) : base($ctxParam) { }

    [Backup] ValidateRequest([string[]] $vmNames, $description) {
        $g = [guid]::NewGuid()
        $v = [string]$g
        $v = $v.Replace("-", "")
        $backupID = $v.substring(0, 10)
        
        ## Check backup name already exists
        $existingBackup = $this.backupRepositery.Find($backupId)

        if ($existingBackup) {
            Write-Error "A backup already exists with id $backupId in the local store" -ErrorAction Stop
        }

        ## Check vm names not specified
        if (-not($vmNames)) {
            Write-Error "No VM specified for backup '$backupId'" -ErrorAction Stop
        }

        $disksCollection = $this.diskRepositery.GetAzDisks() 
        $snapShotsCollection = $this.snapshotRepositery.GetAzSnapshots()

        ## For each vms, build the backup model definition
        $bkpServers = @()
        foreach ($vmName in $vmNames) {
            ## Get the current vm
            $vmInstance = $this.vmRepositery.GetAzVm($vmName)

            if (-not($vmInstance)) {
                Write-Error "VM '$vmName' could not be resolved. Check provided name and start again." -ErrorAction Stop
            }

            ## Get the current disk os, and create a snapshot node
            $snapShots = @()

            $osDisk = $vmInstance.StorageProfile.OsDisk         

            $snapShotName = "$($osDisk.Name)_$($backupID)"
            $existingSnapshot = $snapShotsCollection | Where-Object { $_.Name -eq $snapshotName }

            if ($existingSnapshot) {
                Write-Error "Snapshot name '$($existingSnapshot.Name)' already exists." -ErrorAction Stop
            }

            $existingDisk = $disksCollection | Where-Object { $_.Name -eq $osDisk.Name }

            if (-not($existingDisk)) {
                Write-Error "Disk name '$($existingDisk.Name)' does not exists." -ErrorAction Stop
            }

            $snapShots += [Snapshot]::new($snapShotName, [BackupState]::Offline, $existingDisk.Id, $existingDisk.Name, $existingDisk.Sku.Name, [DiskType]::DiskOS, $null)
            
            ## Get the current data disk, and create a snapshot node
            $dataDisks = $vmInstance.StorageProfile.DataDisks
            if ($dataDisks) {
                foreach ($dataDisk in $dataDisks) {
                    $snapShotName = "$($dataDisk.Name)_$($backupID)"
                    $existingSnapshot = $snapShotsCollection | Where-Object { $_.Name -eq $snapshotName }

                    if ($existingSnapshot) {
                        Write-Error "Snapshot name '$($existingSnapshot.Name)' already exists." -ErrorAction Stop
                    }

                    $existingDisk = $disksCollection | Where-Object { $_.Name -eq $dataDisk.Name }

                    if (-not($existingDisk)) {
                        Write-Error "Disk name '$($existingDisk.Name)' does not exists." -ErrorAction Stop
                    }

                    $snapShots += [Snapshot]::new($snapShotName, [BackupState]::Offline, $existingDisk.Id, $existingDisk.Name, $existingDisk.Sku.Name, [DiskType]::DiskData, $dataDisk.Lun)
                }
            }

            $bkpServers += [Server]::new($vmInstance.Name, [BackupState]::Offline, $snapShots)
        }

        $created = Get-Date -format 'yyyy/MM/dd HH:mm:ss'
        return [Backup]::new($backupID, $description, $created, [BackupState]::Offline, $bkpServers)
    }

    [Void] BackupVm($newBackup, $serverNode) {
        $shouldStartVm = $false

        ## Stop VM IF NEEDED
        if ($this.vmRepositery.IsVmRunningState($serverNode.Name)) {
            $shouldStartVm = $true
            $job = $this.vmRepositery.StopVmAsJob($serverNode.Name)
            $job | Wait-Job
        }

        ## Prepare VM OS SWAP DISK IF NEEDED
        $vmInstance = $this.vmRepositery.GetAzVm($serverNode.Name)

        $vmOsSwapDisk = $this.diskRepositery.GetVmOsSwapDisk($vmInstance)

        if (-not($vmOsSwapDisk)) {
            Write-Error "Error occured while building the backup request, unable to create the VM OS Swap Disk" -ErrorAction Stop
        }

        ## Create snapshots jobs
        Write-Host "{'$($vmInstance.Name)'}' : Creating snapshots ..." -ForegroundColor Green
        $jobs = @()
        foreach ($snapshotNode in $serverNode.Snapshots) {
            try {
                Write-Host "'$($snapshotNode.DiskName)' => '$($snapshotNode.FileName)'"                      
                $jobs += $this.snapshotRepositery.CreateSnapshotAsJob($vmInstance.Location, $snapshotNode.DiskId, $snapshotNode.FileName)
            }
            catch {
                Write-Error -Message $_.Exception.ToString() -ErrorAction Stop
            }
        }
        $jobs | Wait-Job
        $jobsState = $jobs | Receive-Job

        ## Start VM
        if ($shouldStartVm) {
            $job = $this.vmRepositery.StartVmAsJob($serverNode.Name)
            $job | Wait-Job
        }
    }

    [Void] Backup([string[]] $vmNames, $description) {
        Write-Host "Compiling and validating the backup request {'$vmNames'} ..." -ForegroundColor Cyan
        $startTime = $(get-date)

        ## Compiling and get the request
        $newBackup = $this.ValidateRequest($vmNames, $description)
        
        if (-not($newBackup)) {
            Write-Error "Error occured while building the backup request" -ErrorAction Stop
        }
        
        Write-Host "Creating backup ..." -ForegroundColor Cyan
        Write-Host "Id : $($newBackup.ID) ..."
        Write-Host "Description :"
        Write-Host $newBackup.Description
        Write-Host 

        foreach($serverNode in $newBackup.Servers) {
            $this.BackupVm($newBackup, $serverNode)
        }

        $this.backupRepositery.Create($newBackup)

        $elapsedTime = $(get-date) - $startTime
        $totalTime = "Time spent : {0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)
        Write-Host $totalTime -ForegroundColor Cyan
    }
}