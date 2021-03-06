# Az-Backup - Snapshots generation of Azure VMs

Az-Backup is intended to ease the process of backing up and restoring virtual machine disks from your azure subscriptions using snapshots.

It's easy to set up, you have a resource group dedicated to store snapshots and another one with your VMs.
"Creating a backup set, generate a JSON manifest file in Backups folder and allows you to restore the backup sets.

## How to use it ?

* Clone the repositery
* Add you own configuration parameters into the config.json file
```json
{
    "$schema": "http://json-schema.org/schema#",
    "contentVersion": "1.0.0.0",
    "SubscriptionId": "<YOUR SUBSCRIPTION ID>",
    "Snapshots" : {
        "ResourceGroupName" : "<RESOURCE GROUP NAME DEDICATED TO SNAPSHOTS>",
        "StorageType" : "Standard_LRS"
    },
    "Vms" : {
        "ResourceGroupName" : "<VM RESOURCE GROUP NAME>"
    }
}
```
* Backup manifest are stored into your backups folder, don't loose it or you won't be able to restore it

## Create backup

Generate a backup, and a manifest in the Backups folder.

```powershell
New-Backup.ps1 -VMName "<VM-NAME1>", "<VM-NAME2>" ,"<VM-NAME3>" -Description "<YOUR DESCRIPTION>"
```

## Get backups

Resolve all manifests from the backups folder and check azure resources availability

```powershell
Get-Backups.ps1
```

## Restore backup

Restore a backup using the manifest and appropriate snapshots

```powershell
Restore-Backup.ps1 -ID "<BACKUP ID>" -Description "<YOUR DESCRIPTION>"
```

## Delete backup

Delete manifest and snapshot files in azure

```powershell
Delete-Backup.ps1 -ID "<BACKUP ID>"
```

## Manifest Sample (Backups folder)

```json
{
    "ID":  "6a3db9030e",
    "Description":  "",
    "Created":  "\/Date(1563639062000)\/",
    "State":  0,
    "Servers":  [
        {
            "Name":  "ia-sql",
            "State":  0,
            "Snapshots":  [
                {
                    "FileName":  "ia-sql_OsDisk_1_49ddd76d4fd9455b8a1023b48907436d_6a3db9030e",
                    "State":  0,
                    "DiskId":  "/subscriptions/XXXXX/resourceGroups/RGNAME/providers/Microsoft.Compute/disks/ia-sql_OsDisk_1_49ddd76d4fd9455b8a1023b48907436d",
                    "DiskName":  "ia-sql_OsDisk_1_49ddd76d4fd9455b8a1023b48907436d",
                    "DiskSkuName":  "Standard_LRS",
                    "DiskType":  0,
                    "DiskLun":  ""
                },
                {
                    "FileName":  "ia-sql_data_6a3db9030e",
                    "State":  0,
                    "DiskId":  "/subscriptions/XXXXX/resourceGroups/RGNAME/providers/Microsoft.Compute/disks/ia-sql_data",
                    "DiskName":  "ia-sql_data",
                    "DiskSkuName":  "Standard_LRS",
                    "DiskType":  1,
                    "DiskLun":  "0"
                },
                {
                    "FileName":  "ia-sql_logs_6a3db9030e",
                    "State":  0,
                    "DiskId":  "/subscriptions/XXXXX/resourceGroups/RGNAME/providers/Microsoft.Compute/disks/ia-sql_logs",
                    "DiskName":  "ia-sql_logs",
                    "DiskSkuName":  "Standard_LRS",
                    "DiskType":  1,
                    "DiskLun":  "1"
                },
                {
                    "FileName":  "ia-sql_tempdb_6a3db9030e",
                    "State":  0,
                    "DiskId":  "/subscriptions/XXXXX/resourceGroups/RGNAME/providers/Microsoft.Compute/disks/ia-sql_tempdb",
                    "DiskName":  "ia-sql_tempdb",
                    "DiskSkuName":  "Standard_LRS",
                    "DiskType":  1,
                    "DiskLun":  "2"
                }
            ]
        }
    ]
}
```

## Disclaimer 

All information in the services are provided "as is", with no guarantee of completeness, accuracy, timeliness or of the results obtained from the use of this information, and without warranty of any kind, express or implied, including, but not limited to warranties of performance, merchantability and fitness for a particular purpose.

I won't be liable to You or anyone else for any decision made or action taken in reliance on the information given by the services or for any consequential, special or similar damages, even if advised of the possibility of such damages.