function Get-Partner {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ResourceGroupName = $env:MFA_RGN,
        [string]$AutomationAccountName = $env:MFA_AAN,
        [Parameter(Mandatory=$True)]
        [string]$Domain   
    )

    $Partners = Get-Partners -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName

    return ($Partners | Where {($_.DefaultDomain -like $Domain) -or ($_.OtherDomains -like $Domain)})

}