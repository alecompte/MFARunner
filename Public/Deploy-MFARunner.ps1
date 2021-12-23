function Deploy-MFARunner {

  $ConfigPath = $PSScriptRoot + "\..\Azure\config.json"
  


  if (Test-Path $ConfigPath) {
    $Config = Get-Content -Path $ConfigPath | ConvertFrom-Json
  } else {
    Write-Error "Could not find config.json file at $ConfigPath, aborting."
    return
  }


  Write-Host "Welcome to the MFARunner deploy script, make sure to read the guide as you go along."
  Write-Host "First, we'll connect Azure services and Microsoft Online, have your credentials ready"
  Read-Host -Prompt "Press any key to continue"

  try
  {
    $null = Get-MsolDomain -ErrorAction Stop > $null
  }
  catch 
  {
    Write-Host "Connecting to Microsoft Online, you will have a prompt and need to fill your credentials."
    $null = Connect-MsolService -ErrorAction Stop
  }

  Write-Host "Connecting to Azure, you will have a prompt and need to fill in your credentials"
  $null = Connect-AzAccount -ErrorAction Stop

  Write-Host "Completed signing in, now scanning your current setup"

  Write-Host "Currently, we only support creating a new automation account on an EXISTING resource group, make sure to have your resource group already created before proceeding."

  $RessourceGroups = Get-AzResourceGroup

  Write-Host "Please select your ressource group choices are in [X]:"

  $index = 1
  foreach ($rg in $RessourceGroups) {
      Write-Host ("[$index] Name: " + $rg.ResourceGroupName + " Location: " + $rg.Location)
      $index++
  }

  #Remove one because the index is always one over
  $index -= 1

  [Int]$rgc = Read-Host -Prompt "Enter resource group: [1 - $index]"

  while (!$RessourceGroups[($rgc - 1)]) {
    Write-Host "Invalid choice, try again."
    [Int]$rgc = Read-Host -Prompt "Enter resource group: [1 - $index]"
  }

  Write-Host ("You have chosen " + $RessourceGroups[($rgc - 1)].ResourceGroupName)

  Write-Host "We will now create an automation account with this ressource group, you may enter a name without any spaces."
  $AName = Read-Host -Prompt "Automation Account Name"

  while ($AName.Contains(" ")) {
    Write-Host "Invalid character, try again"
    $AName = Read-Host -Prompt "Automation Account Name"
  } 

  $AutomationAccountParams = @{
    Name = $AName
    ResourceGroupName = $RessourceGroups[($rgc - 1)].ResourceGroupName
    Location = $RessourceGroups[($rgc - 1)].Location
  }

  Write-Host "Creating automation account with name $AName"

  $null = New-AzAutomationAccount @AutomationAccountParams -ErrorAction Stop

  Write-Host "Automation account has been created, saving info.."

  $Null = Set-MFAProfile -AutomationAccountName $AName -ResourceGroupName $RessourceGroups[($rgc - 1)].ResourceGroupName
  $Null = Get-MFAProfile
  Write-Host "Info has been saved, you can now auto-load our settings by calling Get-MFAProfile"

  Write-Host "We'll now need some credentials"
  
  foreach ($credObject in $Config.Credentials) {
    Write-Host $credObject.Title
    Write-Host $credObject.Description
    Write-Host "We'll wait while you fetch those credentials, they will be stored securely inside an AzAutomationCredential"
    Read-Host -Prompt "Press any key to continue"
    $creds = Get-Credential 

    While (!$creds) {
      Write-Host "Invalid input"
      Read-Host -Prompt "Press any key to continue"
      $creds = Get-Credential
    }

    $Null = New-AzAutomationCredential -ResourceGroupName $env:MFA_RGN -AutomationAccountName $env:MFA_AAN -Name $credObject.Name -Value $creds -ErrorAction Stop

  }

  Write-Host "Good, we now need to define quite a few variables.."

  foreach ($v in $Config.Variables) {
    if (!$v.Configurable) {
      $null = New-AzAutomationVariable -ResourceGroupName $env:MFA_RGN -AutomationAccountName $env:MFA_AAN -Name $v.Name -Value $v.DefaultValue -Encrypted $v.Encrypted
    } else {
        $val = Auto-Prompt -Var $v

        $Params = @{
          AutomationAccountName = $env:MFA_AAN
          ResourceGroupName = $env:MFA_RGN
          Name = $v.Name
          Encrypted = $v.Encrypted
          Value = $val 
        }

        $null = New-AzAutomationVariable @Params

    }
  }

  Write-Host "All variables were successfully provisioned, we'll now automatically setup some schedules"
  $BaseParams = @{
    AutomationAccountName = $env:MFA_AAN
    ResourceGroupName = $env:MFA_RGN
  }
  $TimeZone = (Get-TimeZone).Id

  $null = New-AzAutomationSchedule @BaseParams -Name "EveryDayMidnight" -TimeZone $TimeZone -StartTime "00:00" -DayInterval 1 -Description "Used for main loop"
  $null = New-AzAutomationSchedule @BaseParams -Name "EveryDay6AM" -TimeZone $TimeZone -StartTime "06:00" -DayInterval 1 -Description "Used for emailer"

  Write-Host "We've setup some schedules, we'll now import our scripts."

  foreach ($rb in $Config.Scripts) {
    $path = $PSScriptRoot + "\..\" + $rb.Path
    Write-Host ("Importing " + $rb.Name)
    Write-Host ("Description: " + $rb.Description)
    $null = Import-AzAutomationRunbook @BaseParams -Path $path -Name $rb.Name -Description $rb.Description -Type PowerShell
  }

  Write-Host "We can't really go ahead and install module manually, so you'll need to install MSOnline in this runbook for PowerShell 5.1, we'll wait while you do that.."
  Read-Host -Prompt "Press any key to continue"

}