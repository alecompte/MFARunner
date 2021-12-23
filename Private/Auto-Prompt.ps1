function Auto-Prompt {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$True)]
    [Object]$Var
  )

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
      [String]$val = Read-Host -Prompt "Enter Value"
      return $val
    }
  }



}