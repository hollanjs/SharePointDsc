function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $SPLogLevelSetting,

        [parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        $InstallAccount
    )


    foreach ($DesiredSetting in $SPLogLevelSetting)
    {
        if ((($DesiredSetting.Area) | Measure-Object).Count -ne 1 -or ($DesiredSetting.Area).contains(",") )
        {
            Write-Verbose -Message "Exactly one log area, or the wildcard character '*' must be provided for each log item area"
            return $null
        }

        if ((($DesiredSetting.Name) | Measure-Object).Count -ne 1 -or ($DesiredSetting.Name).contains(",") )
        {
            Write-Verbose -Message "Exactly one log name, or the wildcard character '*' must be provided for each log item name"
            return $null
        }

        if ($null -eq $DesiredSetting.TraceLevel -and $null -eq $DesiredSetting.EventLevel)
        {
            Write-Verbose -Message "TraceLevel and / or EventLevel must be provided for each Area"
            return $null
        }

        if ($null -ne $DesiredSetting.TraceLevel -and @("None","Unexpected","Monitorable","Medium","Verbose","VerboseEx","default") -notcontains $DesiredSetting.TraceLevel)
        {
            Write-Verbose -Message "TraceLevel $($DesiredSetting.TraceLevel) is not valid, must specify exactly one of None,Unexpected,Monitorable,Medium,Verbose,VerboseEx, or default"
            return $null
        }

        if ($null -ne $DesiredSetting.EventLevel -and @("None","ErrorCritical","Error","Warning","Information","Verbose","default") -notcontains $DesiredSetting.EventLevel)
        {
            Write-Verbose -Message "EventLevel $($DesiredSetting.EventLevel) is not valid, must specify exactly one of None,ErrorCritical,Error,Warning,Informational,Verbose, or default"
            return $null
        }

    }

    Write-Verbose "Getting SP Log Level Settings for provided Areas"

    $result = Invoke-SPDSCCommand -Credential $InstallAccount `
                                 -Arguments $PSBoundParameters `
                                 -ScriptBlock {

         $params = $args[0]

         $CurrentLogLevelSettings = @()
         foreach ($DesiredSetting in $params.SPLogLevelSetting)
         {
            Write-Verbose "Getting SP Log Level Settings for $($DesiredSetting.Area):$($DesiredSetting.Name)"
            $CurrentLogItemSettings = Get-SPLogLevel -Identity "$($DesiredSetting.Area):$($DesiredSetting.Name)"

            #Validate valid log area/name specified.
            if ($null -eq $CurrentLogItemSettings)
            {
                Write-Verbose -Message "Invalid SP Log Area/Name $($DesiredSetting.Area):$($DesiredSetting.Name)"
                return $null
            }

            #TraceLevels
            #if we desire defaults, we will check for default for each item and return as such
            if ($DesiredSetting.TraceLevel -eq "default")
            {
                $SettingAtDefault = $true #assume they are all at default until we find otherwise
                foreach ($setting in $CurrentLogItemSettings) #default values can vary for each area/name, need to check each one.
                {
                    if ($setting.TraceSeverity -ne $setting.DefaultTraceSeverity)
                    {
                        $SettingAtDefault = $false
                    }
                }

                if ($SettingAtDefault)
                {
                    $Tracelevel = 'default'
                }
                else
                {
                    #return a csv list of current unique trace level settings for the provided Area/Name
                    $Tracelevel = [System.String]::Join(",",(($CurrentLogItemSettings.traceseverity) | Select-Object -Unique))
                }

            }
            #default was not specified, so we return the unique current trace severity across all provided settings.
            else
            {
               $Tracelevel = [System.String]::Join(",",(($CurrentLogItemSettings.traceseverity) | Select-Object -Unique))
            }

            #EventLevels
            #if we desire defaults, we will check for default and return as such
            if ($DesiredSetting.EventLevel -eq "default")
            {
                $SettingAtDefault = $true #assume they are all at default until we find otherwise
                foreach ($setting in $CurrentLogItemSettings) #default values can vary for each area/name, need to check each one.
                {
                    if ($setting.EventSeverity -ne $setting.DefaultEventSeverity)
                    {
                        $SettingAtDefault = $false
                    }
                }

                if ($SettingAtDefault)
                {
                    $Eventlevel = 'default'
                }
                else
                {
                    #return a csv list of current unique Event level settings for the provided Area/Name
                    $Eventlevel = [System.String]::Join(",",(($CurrentLogItemSettings.Eventseverity) | Select-Object -Unique))
                }

            }
            #default was not specified, so we return the unique current Event severity across all provided settings.
            else
            {
               $Eventlevel = [System.String]::Join(",",(($CurrentLogItemSettings.Eventseverity) | Select-Object -Unique))
            }


            $CurrentLogLevelSettings += New-Object -TypeName PSObject -Property @{
                Area = $DesiredSetting.Area
                Name = $DesiredSetting.Name
                TraceLevel = $TraceLevel
                EventLevel = $EventLevel
             }


        }

        return @{SPLogLevelSetting = $CurrentLogLevelSettings}

    }

    return $result


}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $SPLogLevelSetting,

        [parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        $InstallAccount
    )

    foreach ($DesiredSetting in $SPLogLevelSetting)
    {
        if ((($DesiredSetting.Area) | Measure-Object).Count -ne 1 -or ($DesiredSetting.Area).contains(",") )
        {
            throw "Exactly one log area, or the wildcard character '*' must be provided for each log item"
        }

        if ((($DesiredSetting.Name) | Measure-Object).Count -ne 1 -or ($DesiredSetting.Name).contains(",") )
        {
            throw "Exactly one log name, or the wildcard character '*' must be provided for each log item"
        }

        if ($null -eq $DesiredSetting.TraceLevel -and $null -eq $DesiredSetting.EventLevel)
        {
            throw "TraceLevel and / or EventLevel must be provided for each Area"
        }

        if ($null -ne $DesiredSetting.TraceLevel -and @("None","Unexpected","Monitorable","Medium","Verbose","VerboseEx","default") -notcontains $DesiredSetting.TraceLevel)
        {
            throw "TraceLevel $($DesiredSetting.TraceLevel) is not valid, must specify exactly one of None,Unexpected,Monitorable,Medium,Verbose,VerboseEx, or default"
        }

        if ($null -ne $DesiredSetting.EventLevel -and @("None","ErrorCritical","Error","Warning","Information","Verbose","default") -notcontains $DesiredSetting.EventLevel)
        {
            throw "EventLevel $($DesiredSetting.EventLevel) is not valid, must specify exactly one of None,ErrorCritical,Error,Warning,Information,Verbose, or default"
        }

    }

    Write-Verbose -Message "Setting SP Log Level settings for the provided areas"

    Invoke-SPDSCCommand -Credential $InstallAccount `
                        -Arguments $PSBoundParameters `
                        -ScriptBlock {

        $params = $args[0]

        foreach ($DesiredSetting in $params.SPLogLevelSetting)
        {

            Write-Verbose "Setting SP Log Level Settings for $($DesiredSetting.Area):$($DesiredSetting.Name)"

            $AllSettings = Get-SPLogLevel -Identity "$($DesiredSetting.Area):$($DesiredSetting.Name)"

            #Validate valid log area/name specified.
            if ($null -eq $AllSettings)
            {
                throw "Invalid SP Log Area/Name $($DesiredSetting.Area):$($DesiredSetting.Name)"
            }

            if ($null -ne $DesiredSetting.TraceLevel)
            {
                if ($DesiredSetting.TraceLevel -eq 'default')
                {
                    #default settings can vary, so we must loop through each one.
                    foreach ($setting in $AllSettings)
                    {
                        Set-SPLogLevel -Identity "$($setting.Area):$($setting.Name)" -TraceSeverity $setting.DefaultTraceSeverity
                    }
                }
                else
                {
                    Set-SPLogLevel -Identity "$($DesiredSetting.Area):$($DesiredSetting.Name)" -TraceSeverity $DesiredSetting.TraceLevel
                }
            }

            if ($null -ne $DesiredSetting.EventLevel)
            {
                if ($DesiredSetting.EventLevel -eq 'default')
                {
                    #default settings can vary, so we must loop through each one.
                    foreach ($setting in $AllSettings)
                    {
                        Set-SPLogLevel -Identity "$($setting.Area):$($setting.Name)" -EventSeverity $setting.DefaultEventSeverity
                    }
                }
                else
                {
                    Set-SPLogLevel -Identity "$($DesiredSetting.Area):$($DesiredSetting.Name)" -EventSeverity $DesiredSetting.EventLevel
                }
            }



        }



    }



}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $SPLogLevelSetting,

        [parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        $InstallAccount
    )

    Write-Verbose -Message "Testing SP Log Level settings for the provided areas"
    $CurrentValues = Get-TargetResource @PSBoundParameters

    if ($null -eq $CurrentValues)
    {
        return $false
    }

    $mismatchedSettingFound = $false

    foreach ($DesiredSetting in $SPLogLevelSetting)
    {
        Write-Verbose -Message "Testing SP Log Level setting for $($DesiredSetting.Area):$($DesiredSetting.Name)"

        $CurrentSetting = $CurrentValues.SPLogLevelSetting | Where-Object -FilterScript {$_.Area -eq $DesiredSetting.Area -and $_.Name -eq $DesiredSetting.Name}

        if (($null -ne $DesiredSetting.TraceLevel -and $CurrentSetting.TraceLevel -ne $DesiredSetting.TraceLevel) -or ($null -ne $DesiredSetting.EventLevel -and $CurrentSetting.EventLevel -ne $DesiredSetting.EventLevel))
        {
            Write-Verbose -Message "SP Log Level setting for $($DesiredSetting.Area):$($DesiredSetting.Name) is not in the desired state"
            $mismatchedSettingFound = $true
        }

    }

    if ($mismatchedSettingFound)
    {
        return $false
    }
    else
    {
        return $true
    }



}


