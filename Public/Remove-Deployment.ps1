function Remove-Deployment {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ResourceGroupName = $env:MFA_RGN,
        [string]$AutomationAccountName = $env:MFA_AAN
    )

    Remove-AzAutomationAccount -Name $AutomationAccountName -ResourceGroupName $ResourceGroupName

}