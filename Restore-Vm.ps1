<#
    .SYNOPSIS  
    Restore a vm from backup
    
    .PARAMETER ID
    Need parameter Name to select the backup name to restore: 
    PS D:\> Restore-Vm.ps1 -ID "adeddfd3e1"

    .EXAMPLE
    Restore-Vm.ps1

    .NOTES  
    FileName:	Restore-Vm.ps1
    Author:		David Rei
    Date:		December 27rd, 2018
#>

Param(
    [Parameter(Mandatory = $true)]
    [string]$BackupID,
    [Parameter(Mandatory = $true)]
    [string]$VMName
)

try {

    ## Region Import Functions
    $0 = $myInvocation.MyCommand.Definition
    $env:dp0 = [System.IO.Path]::GetDirectoryName($0)
    . $env:dp0\Libraries\Entities\Backup.ps1
    . $env:dp0\Libraries\Entities\Parameters.ps1

    . $env:dp0\Libraries\Repositeries\SnapshotRepositery.ps1
    . $env:dp0\Libraries\Repositeries\VmRepositery.ps1
    . $env:dp0\Libraries\Repositeries\DiskRepositery.ps1
    . $env:dp0\Libraries\Repositeries\BackupRepositery.ps1
 
    . $env:dp0\Libraries\Connect.ps1
    . $env:dp0\Libraries\Agents\BackupAgent.ps1
    . $env:dp0\Libraries\Agents\BackupRestoreAgent.ps1
    ## EndRegion
     
    ## Initialize Context
    $parameters = [Parameters]::new($env:dp0)
    $null = [Connect]::new($parameters)
    
    $vmRepositery = [VmRepositery]::new($parameters)  
    $snapshotRepositery = [SnapshotRepositery]::new($parameters)
    $diskRepositery = [DiskRepositery]::new($parameters)
    $backupRepositery = [BackupRepositery]::new($parameters)
    $bVmNeedUpdate = $false

    ## Validate params
    Write-Progress -Id 1 -Activity "Searching for Backup $($BackupID) .." -PercentComplete 0

    $backupFound = $backupRepositery.Find($BackupID)
    $vmInstance = $vmRepositery.GetAzVm($VMName)
    $snapshots = $snapshotRepositery.GetAzSnapshots()

    if (-not($backupFound)) {
        Write-Error "'$BackupID' does not exists in the local store" -ErrorAction Stop
    }

    if (-not($vmInstance)) {
        Write-Error "'$VMName' does not exists in your Azure Subscription" -ErrorAction Stop
    }

    $serverNode = $backupFound.Servers | Where-Object { $_.Name -eq $VMName }

    if (-not($serverNode)) {
        Write-Error "'$VMName' does not exists in the current backup" -ErrorAction Stop
    }

    ## Stopping VM
    if ($vmRepositery.IsVmRunningState($serverNode.Name)) {
        Write-Progress -Id 1 -Activity "Stopping VM  $($serverNode.Name) .." -PercentComplete 10
        Write-Output "Stopping VM  $($serverNode.Name) ... `n"
        $startVm = $true
        $vmStopResult = $vmRepositery.StopVmAsJob($serverNode.Name)
        # Write-Output $vmStopResult
    }

    Write-Output "{'$($backupFound.ID)', '$($vmInstance.Name)'} : Processing ... `n"

    ### BEGIN WIPE VM CONTENT

    ## TODO : Value can be retrieved by the VMRepositery
    $oldAllDisks = @()
    $oldDataDisks = @()
    $oldOsDisk = $vmInstance.StorageProfile.OsDisk | Foreach-Object { "$($_.Name)" }
    $oldAllDisks += $oldOsDisk

    if ($vmInstance.StorageProfile.DataDisks) {
        $oldDataDisks = $vmInstance.StorageProfile.DataDisks | Foreach-Object { "$($_.Name)" }                    
        $oldAllDisks += $oldDataDisks
    }
    ## END TODO

    # Swap OS Disk with Temp OS 
    Write-Progress -Id 1 -Activity "Swapping OS Disk with Temp OS .." -PercentComplete 20
    $tempDisk = $diskRepositery.GetVmOsSwapDisk($vmInstance)

    if (-not($tempDisk)) {
        Write-Error "Error occured while restoring the backup, unable to create the VM OS Swap Disk" -ErrorAction Stop
    }

    if ($tempDisk.Name -ne $oldOsDisk.Name) {
        $bVmNeedUpdate = $true
        Write-Output "{'$($backupFound.ID)', '$($vmInstance.Name)'} : Swapping OS Disk with '$($tempDisk.Name)'... `n"
        $null = Set-AzVMOSDisk -VM $vmInstance -ManagedDiskId $tempDisk.Id -Name $tempDisk.Name                        
    }

    ## Detach all data disks
    Write-Progress -Id 1 -Activity "Detaching all data disks .." -PercentComplete 30

    if ($oldDataDisks) {
        $bVmNeedUpdate = $true
        Write-Output "{'$($backupFound.ID)', '$($vmInstance.Name)'} : Detaching Disks ... `n"
        $vmRepositery.RemoveAzVmDataDisk($vmInstance, $oldDataDisks)
    }

    if ($bVmNeedUpdate) {
        $job = Update-AzVM -ResourceGroupName $vmInstance.ResourceGroupName -VM $vmInstance
        if (-not($job.IsSuccessStatusCode)) {
            Write-Error "Error while updating the Azure Vm" -ErrorAction Stop
        }
    }
            
    ## Delete all old data and OS disks
    Write-Progress -Id 1 -Activity "Deleting all old data and OS disks .." -PercentComplete 40

    $diskToRemoveCollection = @()
    $allOldDiskToRemoveCollection = $diskRepositery.GetAzDisks() | Where-Object { $oldAllDisks -contains $_.Name } | Foreach-Object { "$($_.Name)" }
            
    if ($allOldDiskToRemoveCollection) {
        $diskToRemoveCollection += $allOldDiskToRemoveCollection
    }
            
    $snapshotNodes = $serverNode.Snapshots
    if ($snapshotNodes) {
        foreach ($snapShotNode in $snapshotNodes) {
            if ($diskToRemoveCollection -notcontains $snapShotNode.DiskName) {
                $diskToRemoveCollection += $snapShotNode.DiskName
            }
        }
    }

    Write-Output "{'$($backupFound.ID)', '$($vmInstance.Name)'} : Removing Disks ... `n"

    if ($diskToRemoveCollection) {
        $jobs = @()
        for ($i = 0; $i -lt $diskToRemoveCollection.Length; $i++) {
            $diskName = $diskToRemoveCollection[$i]
            Write-Output "$($diskName) `n"
            $jobs += (Remove-AzDisk -ResourceGroupName $( $parameters.vmResourceGroupName) -DiskName $diskName -Force -AsJob)
        }
        $jobs | Wait-Job
        $jobsState = $jobs | Receive-Job
        #Write-Output $jobsState | Format-Table
    }

    ### END WIPE VM CONTENT
        
    ### BEGIN RESTORE FROM SNAPSHOT

    ## Restore disk Os
    Write-Progress -Id 1 -Activity "Restoring OS disk .." -PercentComplete 50
    $diskOsSnapshotNode = $serverNode.Snapshots | Where-Object { $_.DiskType -eq [DiskType]::DiskOS }                    
    $diskOsSnapshot = $snapshots | Where-Object { $_.Name -eq $diskOsSnapshotNode.FileName }

    Write-Output "{'$($backupFound.ID)', '$($vmInstance.Name)'} : Restoring and attaching OS disk from snapshot ... `n"
    Write-Output "'$($diskOsSnapshotNode.FileName)' => '$($diskOsSnapshotNode.DiskName)' `n"
    $diskConf = New-AzDiskConfig -AccountType $diskOsSnapshotNode.DiskSkuName -Location $vmInstance.Location -SourceResourceId $diskOsSnapshot.Id -CreateOption Copy
    $newOsDisk = New-AzDisk -Disk $diskConf -ResourceGroupName $vmInstance.ResourceGroupName -DiskName $diskOsSnapshotNode.DiskName
    $null = Set-AzVMOSDisk -VM $vmInstance -ManagedDiskId $newOsDisk.Id -Name $newOsDisk.Name

    ## Restore data disks
    Write-Progress -Id 1 -Activity "Restoring data disks .." -PercentComplete 60
    $diskDataSnapshotNodes = $serverNode.Snapshots | Where-Object { $_.DiskType -ne [DiskType]::DiskOS }
    if ($diskDataSnapshotNodes) {

        Write-Output "{'$($backupFound.ID)', '$($vmInstance.Name)'} : Restoring data disks from snapshots ... `n"

        if ($diskDataSnapshotNodes) {
            $jobs = @()

            foreach ($diskDataSnapshotNode in $diskDataSnapshotNodes) {
                Write-Output "'$($diskDataSnapshotNode.FileName)' => '$($diskDataSnapshotNode.DiskName)' `n"
                $dataDiskSnapshot = $snapshots | Where-Object { $_.Name -eq $diskDataSnapshotNode.FileName }
                $diskConf = New-AzDiskConfig -AccountType $diskDataSnapshotNode.DiskSkuName -Location $vmInstance.Location -SourceResourceId $dataDiskSnapshot.Id -CreateOption Copy
                $jobs += (New-AzDisk -Disk $diskConf -ResourceGroupName $vmInstance.ResourceGroupName -DiskName $diskDataSnapshotNode.DiskName -AsJob)
            }

            $null = $jobs | Wait-Job
            $jobsState = $jobs | Receive-Job
            #Write-Output $jobsState
        }

        Write-Output "{'$($backupFound.ID)', '$($vmInstance.Name)'} : Attaching data disks to VM ... `n"

        $azDisksCollection = $diskRepositery.GetAzDisks()

        if ($diskDataSnapshotNodes) {
            $jobs = @()
            for ($i = 0; $i -lt $diskDataSnapshotNodes.Length; $i++) {
                $diskDataSnapshotNode = $diskDataSnapshotNodes[$i]
                Write-Output "'$($diskDataSnapshotNode.DiskName)' => '$($vmInstance.Name)' `n"
                $dataDisk = $azDisksCollection | Where-Object { $_.Name -eq $diskDataSnapshotNode.DiskName }
                $jobState = Add-AzVMDataDisk -VM $vmInstance -Name $dataDisk.Name -CreateOption Attach -ManagedDiskId $dataDisk.Id -Lun $diskDataSnapshotNode.DiskLun
                #Write-Output $jobsState | Format-Table
            }
        }
    }
            
    ## Commit VM Changes
    Write-Progress -Id 1 -Activity "Commit VM changes  .." -PercentComplete 80
    $job = Update-AzVM -ResourceGroupName $vmInstance.ResourceGroupName -VM $vmInstance
    if (-not($job.IsSuccessStatusCode)) {
        Write-Error "Error while updating the Azure Vm" -ErrorAction Stop
    }

    ## Start VM
    if ($startVm) {
        Write-Progress -Id 1 -Activity "Starting VM .." -PercentComplete 90
        $jobState = $vmRepositery.StartVm($vmInstance.Name)
        #Write-Output $jobsState | Format-Table
    }

    Write-Progress -Id 1 -Activity "$($vmInstance.Name) restored" -PercentComplete 100
    Write-Output "{'$($backupFound.ID)', '$($vmInstance.Name)'} : Completed ... `n"

    ### END RESTORE FROM SNAPSHOT    
}
catch {
    Write-Error -Message $_.Exception.ToString();
}