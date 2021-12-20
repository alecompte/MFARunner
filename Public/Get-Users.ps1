function Get-Users {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ResourceGroupName = "AntoinesSandbox",
        [string]$AutomationAccountName = "GlobalAutomation",
        [string]$Domain
    )

    $Users = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name "Users"

    $Users = ConvertFrom-JsonToHashtable -InputObject $Users.Value

    $Partner = Get-Partner -Domain $Domain

    if (!$Partner) {
        Write-Error "Could not find partner with domain $Domain"
        return
    }


    return $Users[$Partner.TenantId]


}