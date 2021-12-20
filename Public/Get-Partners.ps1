


function Get-Partners {
    
    [CmdletBinding()]
    param(
        [string]$ResourceGroupName = $env:MFA_RGN,
        [string]$AutomationAccountName = $env:MFA_AAN
    )


   $azOut = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name "Partners"


   $Partners = ConvertFrom-Json $azOut.Value

   return $Partners
}




