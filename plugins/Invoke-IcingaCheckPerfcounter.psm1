<#
.SYNOPSIS
    Performs checks on various performance counter
.DESCRIPTION
    Invoke-IcingaCheckDirectory returns either 'OK', 'WARNING' or 'CRITICAL', based on the thresholds set.
    Use "Show-IcingaPerformanceCounterCategories" to see all performance counter categories available.
    To gain insight on an specific performance counter use "Show-IcingaPerformanceCounters <performance counter category>"
    e.g '

    More Information on https://github.com/Icinga/icinga-powershell-plugins
.FUNCTIONALITY
    This module is intended to be used to perform checks on different performance counter.
    Based on the thresholds set the status will change between 'OK', 'WARNING' or 'CRITICAL'. The function will return one of these given codes.
.ROLE
    ### Required User Groups

    * Performance Monitor Users
.EXAMPLE
    PS> Invoke-IcingaCheckPerfCounter -PerfCounter '\processor(*)\% processor time' -Warning 60 -Critical 90
    [WARNING]: Check package "Performance Counter" is [WARNING]
    | 'processor1_processor_time'=68.95;60;90 'processor3_processor_time'=4.21;60;90 'processor5_processor_time'=9.5;60;90 'processor_Total_processor_time'=20.6;60;90 'processor0_processor_time'=5.57;60;90 'processor2_processor_time'=0;60;90 'processor4_processor_time'=6.66;60;90
.EXAMPLE
    PS> Invoke-IcingaCheckPerfCounter -PerfCounter @('\processor(*)\% processor time', '\Memory\Available Bytes') -Warnings @('Warning-\processor(*)\% processor time=10', 'Warning-\Memory\Available Bytes=1048576') -Criticals @('Critical-\processor(*)\% processor time=20', 'Critical-\Memory\Available Bytes=1048576') -NoPerfData -Verbosity 2}
    [CRITICAL] Performance Counter [CRITICAL] \Memory\Available Bytes, \processor(*)\% processor time
    \_ [CRITICAL] \Memory\Available Bytes
        \_ [CRITICAL] \Memory\Available Bytes: 1508471000 is greater than threshold 1048576
    \_ [CRITICAL] \processor(*)\% processor time
        \_ [CRITICAL] \processor(_Total)\% processor time: 35.3699 is greater than threshold 20
        \_ [CRITICAL] \processor(0)\% processor time: 60.92133 is greater than threshold 20
        \_ [CRITICAL] \processor(1)\% processor time: 27.85477 is greater than threshold 20
        \_ [CRITICAL] \processor(2)\% processor time: 60.58743 is greater than threshold 20
        \_ [OK] \processor(3)\% processor time: 12.82452
    2
.PARAMETER PerfCounter
    Used to specify an array of performance counter to check against.
.PARAMETER Warnings
    An [array] of strings to set warning thresholds for each checked performance counter. Thresholds have to be defined as follows: "Warning-CounterName=ThresholdValue"
    E.g. for the counter "\processor()% processor time" the treshold has to be defined as follows: "Warning-\processor()% processor time=10"
.PARAMETER Criticals
    An [array] of strings to set critical thresholds for each checked performance counter. Thresholds have to be defined as follows: "Critical-CounterName=ThresholdValue"
    E.g. for the counter "\processor()% processor time" the treshold has to be defined as follows: "Critical-\processor()% processor time=20"
.PARAMETER IncludeCounter
    An [array] of strings to filter for, only including the provided counters. Allows
    wildcard "*" usage
.PARAMETER ExcludeCounter
    An [array] of strings to filter for, excluding the provided counters. Allows
    wildcard "*" usage
.PARAMETER IgnoreEmptyChecks
    Overrides the default behaviour of the plugin in case no check element was found and
    prevent the plugin from exiting UNKNOWN and returns OK instead
.PARAMETER NoPerfData
    Set this argument to not write any performance data
.PARAMETER Verbosity
    Changes the behavior of the plugin output which check states are printed:
    0 (default): Only service checks/packages with state not OK will be printed
    1: Only services with not OK will be printed including OK checks of affected check packages including Package config
    2: Everything will be printed regardless of the check state
    3: Identical to Verbose 2, but prints in addition the check package configuration e.g (All must be [OK])
.INPUTS
    System.String
.OUTPUTS
    System.String
.LINK
    https://github.com/Icinga/icinga-powershell-plugins
.NOTES
#>

function Invoke-IcingaCheckPerfCounter()
{
    param(
        [array]$PerfCounter,
        [array]$Warnings           = @(),
        [array]$Criticals          = @(),
        [array]$IncludeCounter     = @(),
        [array]$ExcludeCounter     = @(),
        [switch]$IgnoreEmptyChecks = $FALSE,
        [switch]$NoPerfData,
        [ValidateSet(0, 1, 2, 3)]
        [int]$Verbosity            = 0
    );

    foreach ($entry in $Warnings) {
        $WarningName = ($entry -split "=")[0]
        $WarningValue = ($entry -split "=")[1]
        New-Variable -Name $WarningName -Value $WarningValue -Force
    }

    foreach ($entry in $Criticals) {
        $CriticalName = ($entry -split "=")[0]
        $CriticalValue = ($entry -split "=")[1]
        New-Variable -Name $CriticalName -Value $CriticalValue -Force
    }

    $Counters     = New-IcingaPerformanceCounterArray -CounterArray $PerfCounter;
    $CheckPackage = New-IcingaCheckPackage -Name 'Performance Counter' -OperatorAnd -Verbose $Verbosity -IgnoreEmptyPackage:$IgnoreEmptyChecks;

    foreach ($counter in $Counters.Keys) {

        if ($counter.Contains('*') -eq $FALSE -And (Test-IcingaArrayFilter -InputObject $counter -Include $IncludeCounter -Exclude $ExcludeCounter) -eq $FALSE) {
            continue;
        }

        $CounterPackage = New-IcingaCheckPackage -Name $counter -OperatorAnd -Verbose $Verbosity -IgnoreEmptyPackage:$IgnoreEmptyChecks;

        if ([string]::IsNullOrEmpty($Counters[$counter].error) -eq $FALSE) {
            $CheckPackage.AddCheck(
                (
                    New-IcingaCheck -Name $counter -NoPerfData
                ).SetUnknown([string]::Format('Internal Counter Error: Failed to fetch performance counter. Error message: {1}', $counter, $Counters[$counter].error), $TRUE)
            );
            continue;
        }

        # Set this to true, which means that by default we always fail
        [bool]$CounterFailed = $TRUE;
        [string]$FirstError  = '';

        foreach ($instanceName in $Counters[$counter].Keys) {
            if ((Test-IcingaArrayFilter -InputObject $instanceName -Include $IncludeCounter -Exclude $ExcludeCounter) -eq $FALSE) {
                continue;
            }

            $instance = $Counters[$counter][$instanceName];

            if ([string]::IsNullOrEmpty($instance.error) -eq $FALSE) {
                if ([string]::IsNullOrEmpty($FirstError)) {
                    $FirstError = [string]($instance.error);
                }
                continue;
            }

            # If we found atleast one working counter in this category, proceed
            $CounterFailed = $FALSE;

            if ($instance -IsNot [hashtable]) {
                $CounterInfo = Get-IcingaPerformanceCounterDetails -Counter $counter;
                $IcingaCheck = New-IcingaCheck -Name $counter -Value $Counters[$counter].Value -MetricIndex $CounterInfo.Category -MetricName $CounterInfo.Counter;
                $IcingaCheckWarning = Get-Variable -Name "Warning-$counter" -ValueOnly -ea ignore
                $IcingaCheckCritical = Get-Variable -Name "Critical-$counter" -ValueOnly -ea ignore
                $IcingaCheck.WarnOutOfRange($IcingaCheckWarning).CritOutOfRange($IcingaCheckCritical) | Out-Null;
                $CounterPackage.AddCheck($IcingaCheck);
                break;
            }

            $CounterInfo = Get-IcingaPerformanceCounterDetails -Counter $instanceName;
            $IcingaCheck = New-IcingaCheck -Name $instanceName -Value $instance.Value -MetricIndex $CounterInfo.Category -MetricName $CounterInfo.CounterInstance;
            $IcingaCheckWarning = Get-Variable -Name "Warning-$counter" -ValueOnly -ea ignore
            $IcingaCheckCritical = Get-Variable -Name "Critical-$counter" -ValueOnly -ea ignore
            $IcingaCheck.WarnOutOfRange($IcingaCheckWarning).CritOutOfRange($IcingaCheckCritical) | Out-Null;
            $CounterPackage.AddCheck($IcingaCheck);
        }

        # If all of over counters failed for some reason, only print one combined error message.
        if ($CounterFailed) {
            if ([string]::IsNullOrEmpty($FirstError)) {
                $FirstError = 'No counter instances could be found';
            }
            $CounterPackage.AddCheck(
                (
                    New-IcingaCheck -Name 'Internal Counter Error' -NoPerfData
                ).SetUnknown([string]::Format('Failed to fetch all instances and objects for this performance counter. First error message: {0}', $FirstError), $TRUE)
            );
        }

        $CheckPackage.AddCheck($CounterPackage);
    }

    return (New-IcingaCheckResult -Check $CheckPackage -NoPerfData $NoPerfData -Compile);
}