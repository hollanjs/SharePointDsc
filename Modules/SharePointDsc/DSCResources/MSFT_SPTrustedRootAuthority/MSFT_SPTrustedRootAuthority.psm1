function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $Certificate,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",

        [System.Management.Automation.PSCredential]
        $InstallAccount
    )
 
    Write-Verbose "Getting Trusted Root Authority with name '$Name'"
    $result = Invoke-SPDSCCommand -Credential $InstallAccount `
                                  -Arguments $PSBoundParameters `
                                  -ScriptBlock {
        $params = $args[0]

        $rootCert = Get-SPTrustedRootAuthority -Identity $params.Name -ErrorAction SilentlyContinue

            $ensure = "Absent"
            if($null -ne $rootCert)
            {
                $ensure = "Present"
            }
            return @{
                Name = $params.Name
                Certificate = $params.Certificate
                Ensure = $ensure
            }
    }

    return $result
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
       [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $Certificate,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",

        [System.Management.Automation.PSCredential]
        $InstallAccount
    )

    Write-Verbose -Message "Setting SPTrustedRootAuthority '$Name'"

    $CurrentValues = Get-TargetResource @PSBoundParameters
    if ($Ensure -eq "Present" -and $CurrentValues.Ensure -eq "Absent") 
    {
        Write-Verbose -Message "Adding SPTrustedRootAuthority '$Name'"
        $result = Invoke-SPDSCCommand -Credential $InstallAccount `
                                      -Arguments $PSBoundParameters `
                                      -ScriptBlock {
            $params = $args[0]
            if(([string]$params.Certificate).Contains("\"))
            {
                $cert = Get-PfxCertificate C:\LiveIDSigningCert.pfx 
                New-SPTrustedRootAuthority -Identity $params.Name -Certificate $cert
            }
            else 
            {
                $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object -FilterScript { $_.Thumbprint -eq $params.Certificate }
                New-SPTrustedRootAuthority -Identity $params.Name -Certificate $cert 
           }
            
        }
    }
    if ($Ensure -eq "Absent")
    {
        Write-Verbose -Message "Removing SPTrustedRootAuthority '$Name'"
        $result = Invoke-SPDSCCommand -Credential $InstallAccount `
                                      -Arguments $PSBoundParameters `
                                      -ScriptBlock {
            $params = $args[0]

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
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $Certificate,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present",

        [System.Management.Automation.PSCredential]
        $InstallAccount
    )

    Write-Verbose -Message "Testing SPTrustedRootAuthority '$Name'"

    $CurrentValues = Get-TargetResource @PSBoundParameters

    return Test-SPDscParameterState -CurrentValues $CurrentValues `
                                    -DesiredValues $PSBoundParameters `
                                    -ValuesToCheck @("Ensure")

}


Export-ModuleMember -Function *-TargetResource

