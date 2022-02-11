<#
    .SYNOPSIS  
    Get all available backups
    
    .EXAMPLE
    Get-Backups.ps1

    .NOTES  
    FileName:	Get-Backups.ps1
    Author:		David Rei
    Date:		December 27rd, 2018
#>

try 
{
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
    $backups = $backupRepositery.FindAll()
    return $backups
}
catch {
    Write-Error -Message $_.Exception.ToString();
}