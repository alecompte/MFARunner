
function Set-User {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ResourceGroupName = $env:MFA_RGN,
        [string]$AutomationAccountName = $env:MFA_AAN,
        [string]$UserPrincipalName,
        [ValidateSet($null, $true, $false)]
        [object]$MFAExempt,
        [ValidateSet($null, $true, $false)]
        [object]$Deleted,
        [ValidateSet($null, $true, $false)]
        [object]$IsScheduled,
        [datetime]$ScheduledDate,
        [string]$EventId,
        [ValidateSet($null, $true, $false)]
        [object]$IsCancelled
    )

    $Domain = $UserPrincipalName.Split("@")[1]

    if (!$Domain) {
        Write-Error "Invalid input"
        return
    }

    $Partner = Get-Partner -Domain $Domain
    if (!$Partner) {
        Write-Error "partner not found"
        return
    }
    $Changes = $False

    $Users = Get-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name "Users"

    $Users = ConvertFrom-JsonToHashtable -InputObject $Users.Value

    $Users[$Partner.TenantId].GetEnumerator() | Foreach-Object {


        if ($_.Email -eq $UserPrincipalName) {

            if ($MFAExempt -ne $Null) {
                $_.MFAExempt = $MFAExempt
                $Changes = $True

            }

            if ($Deleted -ne $Null) {
                $_["Deleted"] = $Deleted
                $Changes = $True
            }

            if ($IsScheduled -ne $Null) {
                if ($IsScheduled) {
                    $_.IsScheduled = $True
                    $hso = [PSCustomObject]@{
                        ScheduledDate = $ScheduledDate.ToString()
                        EventId = $EventId
                        IsCancelled = $IsCancelled
                    } 
                    $_.HistoricalSchedule = ($hso |ConvertTo-Json| Out-String)
                    
                    $Changes = $True

                } else {
                    $_.IsScheduled = $IsCancelled
                    $Changes = $True
                }


            }

            if ($Changes) {
                Set-AzAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name "Users" -Value ($Users | ConvertTo-Json -Compress | Out-String) -Encrypted $False | Out-Null
            } else {
                Write-Output "No changes, not saving"
            }

        }
        


    }




}
