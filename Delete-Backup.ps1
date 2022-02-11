<#
    .SYNOPSIS  
    Delete existing backup
    
    .PARAMETER ID
    Need parameter ID to select the backup to delete: 
    PS D:\> Delete-Backup.ps1 -ID "adeddfd3e1"

    .EXAMPLE
    Delete-Backup.ps1 -ID "adeddfd3e1"

    .NOTES  
    FileName:	Delete-Backup.ps1
    Author:		David Rei
    Date:		December 27rd, 2018
#>

Param(
    [Parameter(Mandatory = $true)]
    [string]$ID
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
    ## EndRegion

    ## Initialize Context
    $parameters = [Parameters]::new($env:dp0)

    ## Connect to Azure
    $null = [Connect]::new($parameters) 

   ## Get backups from local store
   $backupRepositery = [BackupRepositery]::new($parameters)

   Write-Host "Looking for backup '$($ID)' ..."
   $backup = $backupRepositery.Find($ID)

   if (-not($backup)) {
        Write-Error "Backup '($($ID))' does not exists" -ErrorAction Stop
   }

   $backupRepositery.Remove($backup)
}
catch {
    Write-Error -Message $_.Exception.ToString();
}