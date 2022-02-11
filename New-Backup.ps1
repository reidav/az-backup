<#
    .SYNOPSIS  
    Create a new backup for specified VMs
    
    .PARAMETER VMName
    Need parameter VMName to select all targeted VMs: 
    PS D:\> New-Backup.ps1 -VMName "SR-DC1", "SR-DC2" ,"SR-DC3" -Description "Backup AD and DSC"

    .PARAMETER Description
    Need parameter Description to select the new backup description: 
    PS D:\> New-Backup.ps1 -VMName "SR-DC1", "SR-DC2" ,"SR-DC3" -Description "Backup AD and DSC"

    .EXAMPLE
    New-Backup.ps1 -VMName "SR-DC1", "SR-DC2" ,"SR-DC3" -Description "Backup AD and DSC"

    .NOTES  
    FileName:	New-Backup.ps1
    Author:		David Rei
    Date:		December 27rd, 2018
#>

Param(
    [Parameter(Mandatory = $true)]
    [string[]]$VMName,
    [Parameter(Mandatory = $false)]
    [string]$Description
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
     . $env:dp0\Libraries\Agents\BackupRequestAgent.ps1    
     ## EndRegion
    
    ## Initialize Context
    $parameters = [Parameters]::new($env:dp0)

    ## Connect to Azure
    $null = [Connect]::new($parameters) 

    ## Create Backup
    $backupAgent = [BackupRequestAgent]::new($parameters)
    $backupAgent.Backup($VMName, $Description)
}
catch {
    Write-Error -Message $_.Exception.ToString();
}