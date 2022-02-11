<#
    .SYNOPSIS  
    Restore a backup
    
    .PARAMETER ID
    Need parameter Name to select the backup name to restore: 
    PS D:\> Restore-Backup.ps1 -ID "adeddfd3e1"

    .EXAMPLE
    Restore-Backup.ps1

    .NOTES  
    FileName:	Restore-Backup.ps1
    Author:		David Rei
    Date:		December 27rd, 2018
#>

Param(
    [Parameter(Mandatory = $true)]
    [string]$ID,
    [Parameter(Mandatory = $false)]
    [switch]$StartVm
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

     ## Connect to Azure
     $connect = [Connect]::new($parameters) 
 
     ## Create Backup
     $backupAgent = [BackupRestoreAgent]::new($parameters)
     $backupAgent.Restore($ID, $StartVm)
}
catch {
    Write-Error -Message $_.Exception.ToString();
}