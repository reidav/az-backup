Enum BackupState {
    Online = 1
    Offline = 0
}

Enum DiskType {
    DiskOS = 0
    DiskData = 1
}

class Snapshot {
    [string] $FileName
    [BackupState] $State
    [string] $DiskId
    [string] $DiskName
    [string] $DiskSkuName
    [DiskType] $DiskType
    [string] $DiskLun

    Snapshot([string]$fileName, [BackupState]$state, [string]$diskId, [string]$diskName, [string]$diskSkuName, [DiskType]$diskType, [string]$diskLun) {
        $this.FileName = $fileName
        $this.State = $state
        $this.DiskId = $diskId
        $this.DiskName = $diskName
        $this.diskSkuName = $diskSkuName
        $this.DiskType = $diskType
        $this.DiskLun = $diskLun
    }
}

class Server {
    [string] $Name
    [BackupState] $State
    [Snapshot[]] $Snapshots

    Server([string]$name, [BackupState]$state, [Snapshot[]]$snapshots) {
        $this.Name = $name
        $this.State = $state
        $this.Snapshots = $snapshots
    }
}

class Backup {
    [string] $ID
    [string] $Description
    [datetime] $Created
    [BackupState] $State
    [Server[]] $Servers

    Backup([string] $ID, [string]$description, [datetime] $date, [BackupState]$state, [Server[]]$servers) {
        $this.ID = $ID
        $this.Created = $date
        $this.Description = $description
        $this.State = $state
        $this.Servers = $servers
    }
}
