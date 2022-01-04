function Auto-Prompt {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$True)]
    [Object]$Var
  )

  Write-Host "---"
  switch ($Var.Type) {
    "String" {
      Write-Host ("You must set variable " + $var.Name + " of type " + $var.Type)
      Write-Host ("Desciption: " + $var.Description)
      [String]$val = Read-Host -Prompt "Enter Value"
      return $val
    }
    "Bool" {
      Write-Host ("You must set variable " + $var.Name + " of type " + $var.Type)
      Write-Host ("Desciption: " + $var.Description)
      $val = [System.Convert]::ToBoolean((Read-Host -Prompt "Enter Value [True/False]"))
      return $val
    }
    "Integer" {
      Write-Host ("You must set variable " + $var.Name + " of type " + $var.Type)
      Write-Host ("Desciption: " + $var.Description)
      [int]$val = Read-Host -Prompt "Enter Value"
      return $val
    }
    "Path" {
      Write-Host ("You must set variable " + $var.Name + " of type " + $var.Type)
      Write-Host ("Desciption: " + $var.Description)
      Write-Host ("Please note, this is a PATH! The file will be imported using UTF8 enconding")
      [String]$val = Read-Host -Prompt "Enter Value"
      while (!(Test-Path -Path $val)) {
        Write-Host ("Error when trying to read file at path: " + $val)
        Write-Host ("Please try again..")
        [String]$val = Read-Host -Prompt "Enter Value"
      }
      return (Get-Content -Encoding UTF8 -Path $val)
    }
  }

  Write-Host "---"


}