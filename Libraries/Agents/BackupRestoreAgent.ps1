class BackupRestoreAgent : BackupAgent {

    $restoreVmBlock = {
        $path = $args[0]
        . $path\Restore-Vm.ps1 -BackupId $args[1] -VMName $args[2]
    }

    BackupRestoreAgent($ctxParam) : base($ctxParam) { }

    [Void] Restore($backupID, $startVm) {
        $startTime = $(get-date)

        ## Get and check backup state
        Write-Progress -Id 0 -Activity "Looking for backup '$($backupID)' ..." -PercentComplete 0
        $backupFound = $this.backupRepositery.Find($backupID)

        if (-not($backupFound)) {
            Write-Error "'$backupID' does not exists in the local store" -ErrorAction Stop
        }

        if ($backupFound.State -ne [BackupState]::Online) {
            Write-Error "'$($backupFound.Description)' contains some offline components. It could not be restore at the moment" -ErrorAction Stop
        }

        if ($backupFound.Servers) {
            $jobs = @()

            foreach ($serverNode in $backupFound.Servers) {
                $jobs += Start-Job -Name "$($serverNode.Name)" `
                                   -ScriptBlock $this.restoreVmBlock `
                                   -ArgumentList @($this.parameters.azRootPath, $backupID, $serverNode.Name)
            }
           
            $activityDescription = ""
            $allPendingJobs = $jobs | Where-Object { $_.State -ne "Completed" -and $_.State -ne "Failed" }

            while($allPendingJobs) {
                Start-Sleep -Seconds 5
                $percents = $jobs | Foreach-Object { $_.ChildJobs[0].Progress | Select-Object -Last 1 -ExpandProperty PercentComplete }

                $activityDescription = ""
                $percentTotal = 0
                for ($counter=0; $counter -lt $jobs.Length; $counter++)
                {
                    $serverName = $backupFound.Servers[$counter].Name
                    $percentServerName = $percents[$counter]

                    if ($percentServerName -lt 0) { 
                        $percentServerName = 0
                    }

                    $percentTotal += $percentServerName
                    $activityDescription += " $($serverName):$($percentServerName)% "
                }
                [int]$averageProgress =  $percentTotal / $($jobs.Length)
                Write-Progress -Id 0 -Activity "Restoring { $activityDescription }" `
                                     -PercentComplete $averageProgress

                $allPendingJobs = $jobs | Where-Object { $_.State -ne "Completed" -and $_.State -ne "Failed" }
            }

            Write-Progress -Id 0 -Activity "Restoring { $activityDescription }" -PercentComplete 100

            foreach($job in $jobs) {
                $result = Receive-Job -Job $job
                Write-Host $job.Name -ForegroundColor Cyan 
                Write-Host $result
            }

            $jobs | Remove-Job -Force
        }

        $elapsedTime = $(get-date) - $startTime
        $totalTime = "Time spent : {0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)
        Write-Host $totalTime -ForegroundColor Cyan
    }
}