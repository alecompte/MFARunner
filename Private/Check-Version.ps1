function Check-Version {

  $c = Get-ChildItem -Path ($PSScriptRoot + "../Azure/Scripts")
  $versions = @()
  $c | Get-Content -First 1 | %{
    if ($_ -notlike "v:*") {
      Write-Error "Local version is wrong or corrupted, unexpected lines."
    } else {
      $v = $_.Split(":")[1]
      $versions += $v
    }
  }

  foreach ($v in $versions) {
    
  }



}