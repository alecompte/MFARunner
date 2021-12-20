function Set-MFAProfile {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ResourceGroupName = $env:MFA_RGN,
        [string]$AutomationAccountName = $env:MFA_AAN,
        [string]$ProfileName = "MFARunnerConfig"
    )

    $ConfigPath = $Home + "\$ProfileName.json"

    $ConfigObject = [PSCustomObject]@{
        ResourceGroupName = $ResourceGroupName
        AutomationAccountName = $AutomationAccountName
        ProfileName = $ProfileName
    }


    $ConfigObject | ConvertTo-Json | Out-File -FilePath $ConfigPath
    

}