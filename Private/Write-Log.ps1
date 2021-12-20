function Write-Log {
  [CmdletBinding()]
  param(
      [Parameter()]
      [Int32]$DV = 0,
      [Int32]$V = 0,
      [Parameter(ValueFromPipeLine)]
      [string]$Message
  )

  if ($V -ge $DV) {
      Write-Output $Message
  }


}