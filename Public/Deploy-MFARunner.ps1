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
    Get-MsolDomain -ErrorAction Stop > $null
  }
  catch 
  {
    Write-Host "Connecting to Microsoft Online, you will have a prompt and need to fill your credentials."
    Connect-MsolService -ErrorAction Stop
  }

  Write-Host "Connecting to Azure, you will have a prompt and need to fill in your credentials"
  Connect-AzAccount -ErrorAction Stop

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

  New-AzAutomationAccount @AutomationAccountParams -ErrorAction Stop

  Write-Host "Automation account has been created, saving info.."

  Set-MFAProfile -AutomationAccountName $AName -RessourceGroupName $RessourceGroups[($rgc - 1)].ResourceGroupName

  Write-Host "Info has been saved, you can now auto-load our settings by calling Get-MFAProfile"


  

}