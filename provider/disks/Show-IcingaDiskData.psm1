function Show-IcingaDiskData {

    $DisksInformations = Get-CimInstance Win32_DiskDrive;

    [hashtable]$PhysicalDiskData = @{};
    
    if (Get-Command Get-Disk -ErrorAction SilentlyContinue) {
        $GetPhysicalDiskInfo = Get-Disk;
    } else {
        $GetPhysicalDiskInfo    = @();
        $DiskObject = New-Object PSObject -Property @{
            IsReadOnly        = 'NotSupported';
            IsOffline         = 'NotSupported';
            IsSystem          = 'NotSupported';
            IsBoot            = 'NotSupported';
            BusType           = 'NotSupported';
            IsHighlyAvailable = 'NotSupported';
            IsScaleOut        = 'NotSupported';
            IsClustered       = 'NotSupported';
            HealthStatus      = 'NotSupported';
            OperationalStatus = 'NotSupported';
            PartitionStyle    = 'NotSupported';
        }

        $GetPhysicalDiskInfo    = $DiskObject;
    }
    
    foreach ($disk_properties in $DisksInformations) {
        $disk_datails = @{};
        foreach($disk in $disk_properties.CimInstanceProperties) {
            $disk_datails.Add($disk.Name, $disk.Value);
        }

        foreach($Index in $GetPhysicalDiskInfo) {
            if ($disk_properties.Index -eq $Index.DiskNumber) {
                $disk_datails.Add('IsReadOnly', $Index.IsReadOnly);
                $disk_datails.Add('IsOffline', $Index.IsOffline);
                $disk_datails.Add('IsSystem', $Index.IsSystem);
                $disk_datails.Add('IsBoot', $Index.IsBoot);
                $disk_datails.Add('BusType', $Index.BusType);
                $disk_datails.Add('IsHighlyAvailable', $Index.IsHighlyAvailable);
                $disk_datails.Add('IsScaleOut', $Index.IsScaleOut);
                $disk_datails.Add('IsClustered', $Index.IsClustered);
                $disk_datails.Add('HealthStatus', $Index.HealthStatus);
                $disk_datails.Add('OperationalStatus', $Index.OperationalStatus);
                $disk_datails.Add('PartitionStyle', $Index.PartitionStyle);
            }
        }

        $disk_datails.Add('DriveReference', @());
        $PhysicalDiskData.Add($disk_datails.DeviceID, $disk_datails);
    }
    
    $DiskPartitionInfo = Get-WmiObject Win32_DiskDriveToDiskPartition;
    
    [hashtable]$MapDiskPartitionToLogicalDisk = @{};
    
    foreach ($item in $DiskPartitionInfo) {
        [string]$diskPartition = $item.Dependent.SubString(
            $item.Dependent.LastIndexOf('=') + 1,
            $item.Dependent.Length - $item.Dependent.LastIndexOf('=') - 1
        );
        $diskPartition = $diskPartition.Replace('"', '');
    
        [string]$physicalDrive = $item.Antecedent.SubString(
            $item.Antecedent.LastIndexOf('\') + 1,
            $item.Antecedent.Length - $item.Antecedent.LastIndexOf('\') - 1
        )
        $physicalDrive = $physicalDrive.Replace('"', '');
    
        $MapDiskPartitionToLogicalDisk.Add($diskPartition, $physicalDrive);
    }
    
    $LogicalDiskInfo = Get-WmiObject Win32_LogicalDiskToPartition;
    
    foreach ($item in $LogicalDiskInfo) {
        [string]$driveLetter = $item.Dependent.SubString(
            $item.Dependent.LastIndexOf('=') + 1,
            $item.Dependent.Length - $item.Dependent.LastIndexOf('=') - 1
        );
        $driveLetter = $driveLetter.Replace('"', '');
    
        [string]$diskPartition = $item.Antecedent.SubString(
            $item.Antecedent.LastIndexOf('=') + 1,
            $item.Antecedent.Length - $item.Antecedent.LastIndexOf('=') - 1
        )
        $diskPartition = $diskPartition.Replace('"', '');
    
        if ($MapDiskPartitionToLogicalDisk.ContainsKey($diskPartition)) {
            foreach ($disk in $PhysicalDiskData.Keys) {
                [string]$DiskId = $disk.SubString(
                    $disk.LastIndexOf('\') + 1,
                    $disk.Length - $disk.LastIndexOf('\') - 1
                );
    
                if ($DiskId.ToLower() -eq $MapDiskPartitionToLogicalDisk[$diskPartition].ToLower()) {
                    $PhysicalDiskData[$disk]['DriveReference'] += $driveLetter;
                }
            }
        }
    }
    
    return $PhysicalDiskData;

}