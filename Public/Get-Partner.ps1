function Get-Partner {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ResourceGroupName = "AntoinesSandbox",
        [string]$AutomationAccountName = "GlobalAutomation",
        [Parameter(Mandatory=$True)]
        [string]$Domain   
    )

    $Partners = Get-Partners -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName

    return ($Partners | Where {($_.DefaultDomain -like $Domain) -or ($_.OtherDomains -like $Domain)})

}