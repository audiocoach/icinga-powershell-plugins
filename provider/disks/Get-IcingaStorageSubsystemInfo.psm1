function Get-IcingaStorageSubsystemInfo()
{

    $StorageSubsystems       = Get-IcingaWindowsInformation MSFT_StorageSubsystem -Namespace 'root\Microsoft\Windows\Storage';

    foreach ($StorageSubsystem in $StorageSubsystems) {

        [hashtable]$StorageSubsystemInfo = @{};
        $StorageSubsystemInfo = @{
            'FriendlyName' = $StorageSubsystem.FriendlyName;
            'HealthStatus' = $StorageSubsystem.HealthStatus;
        }

        $StorageSubsystemInfo.Add('OperationalStatus', @{ });
        if ($null -ne $StorageSubsystem.OperationalStatus) {
            $OperationalStatus = @{ };

            foreach ($entry in $StorageSubsystem.OperationalStatus) {
                if (Test-Numeric $entry) {
                    Add-IcingaHashtableItem -Hashtable $OperationalStatus -Key ([int]$entry) -Value (Get-IcingaProviderEnumData -Enum $ProviderEnums -Key '$StorageOperationalStatus' -Index $entry) | Out-Null;
                } else {
                    if ($ProviderEnums.StorageOperationalStatus.Values -Contains $entry) {
                        foreach ($opStatus in $ProviderEnums.DiskOperationalStatus.Keys) {
                            $opStatusValue = (Get-IcingaProviderEnumData -Enum $ProviderEnums -Key 'DiskOperationalStatus' -Index $opStatus);
                            if ($opStatusValue.ToLower() -eq ([string]$entry).ToLower()) {
                                Add-IcingaHashtableItem -Hashtable $OperationalStatus -Key ([int]$opStatus) -Value $entry | Out-Null;
                                break;
                            }
                        }
                    }
                }
            }

            $StorageSubsystemInfo.OperationalStatus = $OperationalStatus;
        } else {
            $StorageSubsystemInfo.OperationalStatus = @{ 0 = 'Unknown'; };
        }
    }

    return $StorageSubsystemInfo;
}