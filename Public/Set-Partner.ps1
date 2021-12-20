function Set-Partner {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ResourceGroupName = "AntoinesSandbox",
        [string]$AutomationAccountName = "GlobalAutomation",
        [Parameter(Mandatory=$True)]
        [string]$Domain,
        [Parameter(Mandatory=$False)]
        [ValidateSet($null, $true, $false)]
        [object]$Managed,
        [ValidateSet($null, $true, $false)]
        [object]$MFAEnabled,
        [ValidateSet($null, $true, $false)]
        [object]$Enabled

    )

    $Partners =  Get-Partners -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName 
    $P = $Partners | Where {($_.DefaultDomain -like $Domain) -or ($_.OtherDomains -like $Domain)}
    if ($P) {

        if ($Managed -ne $Null) {
            $P.Managed = $Managed
        }

        if ($MFAEnabled -ne $Null) {
            $P.MFAEnabled = $MFAEnabled
        }

        if ($Enabled -ne $Null) {
            $P.Enabled = $Enabled
        }

    } else {
        Write-Error "Could not find partner with domain $Domain"
    }

    Set-AzAutomationVariable -Name Partners -AutomationAccountName $AutomationAccountName -ResourceGroupName $ResourceGroupName -Encrypted $False -Value ($Partners | ConvertTo-Json -Compress| Out-String) | Out-Null

    return $P

}
