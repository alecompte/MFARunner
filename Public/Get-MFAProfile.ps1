function Get-MFAProfile {
  [CmdletBinding()]
  param(
      [Parameter()]
      [string]$ProfileName = "MFARunnerConfig"
  )

  $ConfigPath = $Home + "\$ProfileName.json"

  $Config = Get-Content -Path $ConfigPath | ConvertFrom-Json

  $env:MFA_AAN = $Config.AutomationAccountName
  $env:MFA_RGN = $Config.ResourceGroupName
  

}