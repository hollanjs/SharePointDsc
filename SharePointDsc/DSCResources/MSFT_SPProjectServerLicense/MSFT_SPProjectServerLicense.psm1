$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'
$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SharePointDsc.Util'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SharePointDsc.Util.psm1')

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [String]
        $IsSingleInstance,

        [Parameter()]
        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present",

        [Parameter()]
        [System.String]
        $ProductKey,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $InstallAccount
    )

    Write-Verbose -Message "Getting license status for Project Server"

    if ((Get-SPDscInstalledProductVersion).FileMajorPart -lt 16)
    {
        throw [Exception] ("Support for Project Server in SharePointDsc is only valid for " + `
                "SharePoint 2016 and 2019.")
    }

    $result = Invoke-SPDscCommand -Credential $InstallAccount `
        -Arguments $PSBoundParameters `
        -ScriptBlock {
        $params = $args[0]

        try
        {
            $currentLicense = Get-ProjectServerLicense

            # Check if result is an array. If so, the result is multi-lined.
            # We only need the first line.
            if ($currentLicense -is [Array])
            {
                $currentLicense = $currentLicense[0]
            }

            # SP2016 value is "Project Server 2016 : Active" (space after 2016)
            # SP2019 value is "Project Server 2019: Active" (no space after 2019)
            # SP2019 Preview value is "Project Server 2019 Preview: Active"
            $regex = "Project Server [0-9]{4}\s*\w*: (?<Status>[a-zA-Z]+)"

            if ($currentLicense -match $regex)
            {
                if ($Matches.Status -eq "Active")
                {
                    $status = "Present"
                }
                else
                {
                    $status = "Absent"
                }

                return @{
                    IsSingleInstance = "Yes"
                    Ensure           = $status
                    ProductKey       = $params.ProductKey
                    InstallAccount   = $params.InstallAccount
                }
            }
            else
            {
                Write-Verbose -Message "Unable to determine the license status for Project Server"
                return @{
                    IsSingleInstance = "Yes"
                    Ensure           = "Absent"
                    ProductKey       = $params.ProductKey
                    InstallAccount   = $params.InstallAccount
                }
            }
        }
        catch
        {
            Write-Verbose -Message "Unable to determine the license status for Project Server"
            return @{
                IsSingleInstance = "Yes"
                Ensure           = "Absent"
                ProductKey       = $params.ProductKey
                InstallAccount   = $params.InstallAccount
            }
        }
    }
    return $result
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [String]
        $IsSingleInstance,

        [Parameter()]
        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present",

        [Parameter()]
        [System.String]
        $ProductKey,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $InstallAccount
    )

    Write-Verbose -Message "Setting Project Server License status"

    if ((Get-SPDscInstalledProductVersion).FileMajorPart -lt 16)
    {
        throw [Exception] ("Support for Project Server in SharePointDsc is only valid for " + `
                "SharePoint 2016 and 2019.")
    }

    if ($Ensure -eq "Present" -and $PSBoundParameters.ContainsKey("ProductKey") -eq $false)
    {
        throw [Exception] "ProductKey is required when Ensure equals 'Present'"
    }

    $currentValues = Get-TargetResource @PSBoundParameters

    if ($currentValues.Ensure -ne $Ensure)
    {
        # License status does not match
        if ($Ensure -eq "Present")
        {
            Invoke-SPDscCommand -Credential $InstallAccount `
                -Arguments $PSBoundParameters `
                -ScriptBlock {

                $params = $args[0]
                Enable-ProjectServerLicense -key $params.ProductKey
            }
        }
        if ($Ensure -eq "Absent")
        {
            Invoke-SPDscCommand -Credential $InstallAccount `
                -Arguments $PSBoundParameters `
                -ScriptBlock {

                Disable-ProjectServerLicense
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
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [String]
        $IsSingleInstance,

        [Parameter()]
        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present",

        [Parameter()]
        [System.String]
        $ProductKey,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $InstallAccount
    )

    Write-Verbose -Message "Testing Project Server License status"

    $PSBoundParameters.Ensure = $Ensure

    $CurrentValues = Get-TargetResource @PSBoundParameters

    Write-Verbose -Message "Current Values: $(Convert-SPDscHashtableToString -Hashtable $CurrentValues)"
    Write-Verbose -Message "Target Values: $(Convert-SPDscHashtableToString -Hashtable $PSBoundParameters)"

    $result = Test-SPDscParameterState -CurrentValues $CurrentValues `
        -Source $($MyInvocation.MyCommand.Source) `
        -DesiredValues $PSBoundParameters `
        -ValuesToCheck @("Ensure")

    Write-Verbose -Message "Test-TargetResource returned $result"

    return $result
}

Export-ModuleMember -Function *-TargetResource
