##Todo: Change UserTable behaviour to handle deleted users, recreate it everytime.

##Users
$CutOffTimeWindow = 60


$creds = Get-AutomationPSCredential -Name 'azautomation'
Connect-MsolService -Credential $creds

function ConvertFrom-JsonToHashtable {

    <#
    .SYNOPSIS
        Helper function to take a JSON string and turn it into a hashtable
    .DESCRIPTION
        The built in ConvertFrom-Json file produces as PSCustomObject that has case-insensitive keys. This means that
        if the JSON string has different keys but of the same name, e.g. 'size' and 'Size' the comversion will fail.
        Additionally to turn a PSCustomObject into a hashtable requires another function to perform the operation.
        This function does all the work in step using the JavaScriptSerializer .NET class
    #>

    [CmdletBinding()]
    param(

        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
        [AllowNull()]
        [string]
        $InputObject,

        [switch]
        # Switch to denote that the returning object should be case sensitive
        $casesensitive
    )

    # Perform a test to determine if the inputobject is null, if it is then return an empty hash table
    if ([String]::IsNullOrEmpty($InputObject)) {

        $dict = @{}

    } else {

        # load the required dll
        [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
        $deserializer = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
        $deserializer.MaxJsonLength = [int]::MaxValue
        $dict = $deserializer.DeserializeObject($InputObject)

        # If the caseinsensitve is false then make the dictionary case insensitive
        if ($casesensitive -eq $false) {
            $dict = New-Object "System.Collections.Generic.Dictionary[System.String, System.Object]"($dict, [StringComparer]::OrdinalIgnoreCase)
        }

    }

    return $dict
}


$Partners = (ConvertFrom-Json -InputObject (Get-AutomationVariable -Name "Partners"))


$UserTable = Get-AutomationVariable -Name Users 
if (!$UserTable -or ($UserTable -eq $Null) -or ($UserTable -eq "") -or ($UserTable -eq "whatever")) {
    $UserTable = @{}
} else {
    $UserTable = (ConvertFrom-JsonToHashtable -InputObject $UserTable)
}

$Statistics = Get-AutomationVariable -Name Statistics
if ($Statistics -eq "empty") {
    $Statistics = @()
} else {
    $Statistics = ConvertFrom-Json -InputObject $Statistics
}



## Recalculate MFA Percentage for each tenants, add new domains
## Structure of object is as follow:
##  $PartnerInfo = [pscustomobject]@{
##      DefaultDomain = ""
##      OtherDomains = @()
##      TenantId = $p.TenantId
##      LicensedUserCount = 0
##      Enabled = $false
##      MFAEnabled = $false
##      PercentageMFA = ""
##      Managed = $false
##      PercentageMFANumeric = 0
##      MFADetails = [PSCustomObject]@{
##          UsersWithMfa = 0
##          UsersWithoutMfa = 0
##  }


foreach ($p in $Partners) {

    $domains = Get-MsolDomain -TenantId $p.TenantId
    foreach ($d in $domains) {

        if (($p.DefaultDomain -eq $d.Name) -or ($p.OtherDomains -contains $d.Name)) {
            ## Everything is there
        } else {
            if ($d.IsDefault -eq $True) {
                $p.DefaultDomain = $d.Name
            } else {
                $p.OtherDomains += $d.Name
            }
        }

    }

    $PartnerStats = $Statistics | Where {$_.TenantId -eq $p.TenantId}

    if (!$PartnerStats) {
        $PartnerStats = [PSCustomObject]@{
            TenantId = $p.TenantId
            Stats = @()
        }
        $Statistics += $PartnerStats
        $PartnerStats = $Statistics | Where {$_.TenantId -eq $p.TenantId}
    } 

    if ($p.LicensedUserCount -gt 1) {
        $PartnerStats.Stats += [PSCustomObject]@{
            Date = (Get-Date).ToString()
            UsersWithMfa = $p.MFADetails.UsersWithMFA
            UsersWithoutMfa = $p.MFADetails.UsersWithoutMfa
            PercentageMFANumeric = $p.PercentageMFANumeric
            PercentageMFA = $p.PercentageMFA
            LicensedUserCount = $p.LicensedUserCount
        }
    }


    $LicensedUsers = Get-MsolUser -TenantId $p.TenantId -All| Where {$_.IsLicensed -eq $True}

    $p.LicensedUserCount = $LicensedUsers.Count

    if ($p.LicensedUserCount -gt 1) {
        ## Check if MFA is $Contracts = Get-MsolPartnerContract -Allenforced


        $p.MFADetails.UsersWithMfa = ($LicensedUsers | Where {($_.StrongAuthenticationRequirements.State -eq "Enforced") -or ($_.StrongAuthenticationRequirements.State -eq "Enabled")}).Count
        $p.MFADetails.UsersWithoutMfa = ($p.LicensedUserCount - $p.MFADetails.UsersWithMfa)
        $p.PercentageMFANumeric = ($p.MFADetails.UsersWithMfa/$p.LicensedUserCount)
        $p.PercentageMFA = ($p.MFADetails.UsersWithMfa/$p.LicensedUserCount).ToString("P")



    }

    ## User processing space

    ## Only go forward if the partner is managed
    if ($p.Managed) {

        # Does the tenant exist in the table
        if (!$UserTable.ContainsKey($p.TenantId.ToString())) {
            $UserTable[$p.TenantId.ToString()] = @()
        }


        ##Get all users that have a legit email and no license
        $Users = (Get-MsolUser -All -TenantId $p.TenantId | Where {($_.IsLicensed -eq "true") -and ($_.UserPrincipalName -notlike '*.onmicrosoft.com')})

        
        foreach ($u in $Users) {

            ##User already exist in table, update it
            if ($UserTable[$p.TenantId.ToString()] | Where {$_.Email -eq $u.UserPrincipalName}) {

                $user = $UserTable[$p.TenantId.ToString()] | Where {$_.Email -eq $u.UserPrincipalName}

                ## This is a recent addition, so we add the value
                ## Only do this if the partner is MFAEnabled and Enabled
                if (!$user.CutOffDate -and !$user.MFAEnabled -and $p.MFAEnabled -and $p.Enabled) {
                    $user.CutOffDate = (Get-Date).AddDays($CutOffTimeWindow).ToString()
                }
                
                ## Is the user scheduled? if yes we check to see if it's really enabled
                if ($user.IsScheduled -and $user.HistoricalSchedule) {
                    

                    $lastSchedule = ConvertFrom-Json -InputObject $user.HistoricalSchedule

                    if ($lastSchedule.IsCancelled) {
                        #$user.IsScheduled = $False
                        $uemail = $user.Email
                        Write-Output "Canceling scheduled status for user $uemail"
                    }

                    $parsedDate = [datetime]::Parse($lastSchedule.ScheduledDate)

                    ## It's now past the date of the last meeting, let's have a look
                    if (((Get-Date) -gt $parsedDate.AddDays(1)) -and $parsedDate) {
                        $user.IsScheduled = $False
                        
                        $uemail = $user.Email
                        $curDate = (Get-Date).ToString()
                        $scDate = $parsedDate.ToString()
                        $scxDate = $lastSchedule.ScheduledDate
                        Write-Output "Canceling scheduled status for user $uemail, expired."
                        Write-Output "cur: $curDate exp: $scDate"
                    }


                }

                # Check if MFA is enabled
                if ((($u.StrongAuthenticationRequirements.State -eq "Enforced") -or ($u.StrongAuthenticationRequirements.State -eq "Enabled")) -and !$user.MFAEnabled) {
                    ## MFA Was activated
                    ## Do something I guess
                    $user.MFAEnabled = $True
                    $user.MFAEnabledDate = (Get-Date).ToString()
                }

                ##Force enable MFA if cutoff is over
                if (!$user.IsScheduled -and !$user.MFAEnabled -and !$user.MFAExempt -and ((Get-AutomationVariable -Name 'EnableMFACutoff') -and $p.Enabled -and $p.MFAEnabled)) {
                    #User is not scheduled
                    #User does not have MFA enabled
                    #User is not MFA Exempt
                    #Feature is enabled
                    #We force enable MFA here
                    if ($user.CutOffDate -ne $False) {
                        if ((Get-Date) -gt $user.CutOffDate) {
                            $Username = $user.Email
                            Write-Output "Force enabling MFA for user: $Username"
                            $sa = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
                            $sa.RelyingParty = "*"
                            $sa.State = "Enabled"
                            $sar = @($sa)

                            Set-MsolUser -TenantId $p.TenantId -UserPrincipalName $u.UserPrincipalName -StrongAuthenticationRequirement $sar
                        }   
                    }
                }
                
            } else {
                ## User not found
                ## Adding it

                $UserDetails = [PSCustomObject]@{
                    DisplayName = $u.DisplayName
                    Email = $u.UserPrincipalName
                    MFAEnabled = ($u.StrongAuthenticationRequirements.State -eq "Enforced") -or ($u.StrongAuthenticationRequirements.State -eq "Enabled")
                    MFAEnabledDate = $False
                    MFAExempt = $False
                    IsScheduled = $False
                    CutOffDate = $false
                    ContactAttempts = @()
                    HistoricalSchedule = @()
                }
                
                if ($p.MFAEnabled -and $p.Managed -and $p.Enabled) {
                    $UserDetails.CutOffDate = (Get-Date).AddDays($CutOffTimeWindow).ToString()
                }

                if ($UserDetails.MFAEnabled) {
                    $UserDetails.MFAEnabledDate = (Get-Date).ToString()
                }

                $UserTable[$p.TenantId.ToString()] += $UserDetails
            }
        }
        


    }

}

Set-AutomationVariable -Name Statistics -Value ($Statistics | ConvertTo-Json -Compress).ToString()
Set-AutomationVariable -Name Partners -Value ($Partners | ConvertTo-Json -Compress).ToString()
Set-AutomationVariable -Name Users -Value ($UserTable | ConvertTo-Json -Compress).ToString()