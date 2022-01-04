function Deploy-MFARunner {
  [CmdletBinding()]
  param(

  )
  $ConfigPath = $PSScriptRoot + "\..\Azure\config.json"

  if (Test-Path $ConfigPath) {
    $Config = (Get-Content -Path $ConfigPath | ConvertFrom-Json)
  } else {
    Write-Error "Could not find config.json file at $ConfigPath, aborting."
    return
  }

  $Config | Out-String | Write-Verbose

  if (!$Config.Version) {
    Write-Error "Config is wrong somehow, here's raw file content"
    Write-Output $ConfigPath
    Get-Content -Path $ConfigPath | Write-Output
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
2
  $calendlyAPIKey = ""

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
        
        ## We must keep this for future use!
        if ($v.Name -eq "calendlyApiKey") {
          $calendlyAPIKey = $val
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

  $Tomorrow = (Get-Date -Hour 00 -Minute 00 -Second 00).AddDays(1)
  $TomorrowSixAm = (Get-Date -Hour 06 -Minute 00 -Second 00).AddDays(1)

  $null = New-AzAutomationSchedule @BaseParams -Name "EveryDayMidnight" -TimeZone $TimeZone -StartTime $Tomorrow -DayInterval 1 -Description "Used for main loop"
  $null = New-AzAutomationSchedule @BaseParams -Name "EveryDay6AM" -TimeZone $TimeZone -StartTime $TomorrowSixAm -DayInterval 1 -Description "Used for emailer"

  Write-Host "We've setup some schedules, we'll now import our scripts."

  foreach ($rb in $Config.Scripts) {
    $path = $PSScriptRoot + "\..\" + $rb.Path
    Write-Host ("Importing " + $rb.Name)
    Write-Host ("Description: " + $rb.Description)
    $null = Import-AzAutomationRunbook @BaseParams -Path $path -Name $rb.Name -Description $rb.Description -Type PowerShell
    $null = Publish-AzAutomationRunbook @BaseParams -Name $rb.Name

    ## If we have a webhook, we deploy it here.
    if ($rb.WebHook) {
      ## This should be adusjted so it's not only for calendly
      Write-Host "Now creating webhook for Calendly"
      $WebhookError = "noerror"

      $wh = New-AzAutomationWebhook @BaseParams -Name $rb.WebHook.Name -RunbookName $rb.Name -IsEnabled $rb.WebHook.IsEnabled -ExpiryTime ((Get-Date).AddYears(2)) -ErrorAction Stop -ErrorVariable WebHookError
      
      if ($WebhookError -ne "noerror") {
        Write-Error $WebhookError
        Write-Error -Message "Fatal error, will clean install."
        Remove-Deployment @BaseParams
        return $WebhookError
      }
      
      if ($rb.WebHook.Name -eq "CalendlyHook") {
        Write-Output ""
        Write-Output "The next line is your WebHook URI. KEEP IT. We'll attempt to automatically hook it to calendly API"
        Write-Output $wh.WebhookURI
        Read-Host "Press any key to continue..."
        $cRes = New-CalendlyHook -RunbookUri $wh.WebhookURI -APIKey $calendlyAPIKey
      } elseif ($rb.WebHook.Name -eq "CalendlyEventFinder") {
        Write-Host "We'll now try to figure out which event is yours, you'll need to book a test appointment, but not just now."
        
        $previousCount = 1

        Write-Host "Creating calendly webhook"

        $cRes = New-CalendlyHook -RunbookUri $wh.WebhookURI -APIKey $calendlyAPIKey

        if ($cRes.statusCode -eq 200) {
          Write-Output "Create successful.."
          Write-Output "Now, you'll need to book an event using the exact link you'll send to people, event data will be displayed here"
          $RightEvent = $False 

          while (!$RightEvent) {
            $tempHits = (Get-AzAutomationVariable -Name "tempCalendlyHits" @BaseParams).Value
            if ($tempHits -ne "empty") {
              $tempHits = ConvertFrom-Json $tempHits
            }
            
            if ($tempHits.Count -gt $previousCount) {
              ##We've got a new one apparently
              $h = $tempHits[$tempHits.Cunt]

              if (($h -ne "empty") -or ($h -ne "notanevent")) {
                Write-Output ("We received a new event, you have to see if this is the right one..")
                Write-Output ("Event Name: " + $h.resource.name)
                Write-Output ("Start time: " + $h.resource.start_time)
                Write-Output ("Type: " + $h.resource.event_type)
                Write-Output ("Guests: ")
                foreach ($guest in $h.resource.event_guests) {
                  Write-Output (" - Email: "+ $gues.email)
                }
                
                Write-Output ("Is this right?")
                [string]$c = Read-Host -Prompt "[Y]es / [N]o"
                if ($c.ToLower() -eq "y") {
                  $RightEvent = $True
                  ##Handle right event here
                  $null = Set-AzAutomationVariable @BaseParans -Name "calendlyAcceptableEvent" -Value $h.resource.event_type -Encrypted $False
                  Write-Output "We've set the variable calendlyAcceptableEvent, the webhook should now fully work. We'll clean up."
                  $null = Remove-AzAutomationRunbook @BaseParams -Name "CalendlyEventFinder" -Force
                  Write-Host "Done"
                } else {
                  $previousCount = $tempHits.Count 
                }

              } else {
                Write-Verbose "Doing nothing, wrong type.."  
              }


            } else {
              ##Not hit, let's wait a bit..
              Write-Host "No hit.. Waiting"
              Start-Sleep -Seconds 5
            }

          }
          


        } else {
          Write-Error "Unable to create calendly hook"
        }


      }
    }

  }

  Write-Host "Alright, we're almost almost done. You just need to run Setup-Partners to push your partner tenants and all will be over."

  Write-Host "We can't really go ahead and install a powershell module from the gallery manually, so you'll need to install MSOnline in this runbook for PowerShell 5.1, we'll wait while you do that.."
  Read-Host -Prompt "Press any key to continue"




}