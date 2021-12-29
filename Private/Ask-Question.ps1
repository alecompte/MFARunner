function Ask-Question {
  param(
    [Object]$Question
  )

  Write-Output $Question.Text
  [string]$val = Read-Host -Prompt "[Y]es / [N]o"

  while (($val.ToLower() -ne "y") -or ($val.ToLower() -ne "n")) {
    [string]$val = Read-Host -Prompt "[Y]es / [N]o" 
  }

  if ($val.ToLower() -eq "y") {
    return $True
  } else {
    
    if ($Question.Required) {
      Write-Output "This is MANDATORY, you must have this already."
      Write-Output $Question.HelpLink
      return $False 

    }



  }
  return $true
}