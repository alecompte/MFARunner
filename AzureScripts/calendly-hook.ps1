Param(
    [Parameter(Mandatory=$True)]
    [object]$WebhookData
)

$apiToken = Get-AutomationVariable -Name 'calendlyapi'
$acceptableEvent = Get-AutomationVariable -Name 'calendlyAcceptableEvent'


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
$UserTable = ConvertFrom-JsonToHashtable -InputObject (Get-AutomationVariable -Name 'Users')
$FoundEvent = $False

if ($WebhookData) {

    $eventData = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)

    if (($eventData.event -eq "invitee.created") -or ($eventData.event -eq "invitee.cancelled")) {

        $Headers = @{
            "authorization" = $apiToken
            "Content-Type" = 'application/json'
        }

        $response = Invoke-RestMethod -Uri $eventData.payload.event -Method GET -Headers $Headers -UseBasicParsing

        if ($response.resource.event_type -eq $acceptableEvent) {
            Write-Output "This is the right event type"



            #Find the user
            
            $Partners = ConvertFrom-Json -InputObject (Get-AutomationVariable -Name 'Partners')

            $domain = $eventData.payload.email.ToString().Split("@")[1]
            Write-Output ($Partners.Count)
            $P = $Partners | Where {($_.DefaultDomain -like $domain) -or  ($_.OtherDomains -contains $domain)}

            if (!$P) {
                Write-Output "Tenant not found for domain $domain"
                return
            } else {
                $tId = $P.TenantId
                $d = $P.DefaultDomain
                Write-Output "Found tenant $d id $tId"
            }

            $NewUserTable = @()

            $UserTable[$P.TenantId] | Foreach-Object {
                $usr = $_ | Where {$_.Email -eq $eventData.payload.email}
                
                if ($usr) {
                    $dName = $usr.DisplayName
                    Write-Output "Found User $dName"
                    if ($eventData.event -eq "invitee.created") {
                        $FoundEvent = $True
                        
                        $usr.IsScheduled = $True

                        $ScheduleObject = [PSCustomObject]@{
                            EventId = $response.resource.uri
                            ScheduledDate = $response.resource.start_time
                            IsCancelled = $false
                        }

                    
                        $usr["HistoricalSchedule"] = (ConvertTo-Json -InputObject $ScheduleObject | Out-String)
                                                
                        
                        $UName = $eventData.payload.email
                        $Date = $response.resource.start_time
                        $EventId = $Response.resource.uri
                        Write-Output "Successfully added event to table, $Uname at $Date event $EventId"
                        Write-Output ($usr.Values)
                    } else {
                        if ($usr.IsScheduled) {
                            $usr.IsScheduled = $False
                            $usr.HistoricalSchedule = ""

                        } else {
                            Write-Output "Event Cancelled but event not found, weird."
                        }
                    }


                    $NewUserTable += $usr
                } else {
                    $NewUserTable += $_
                }
        
            }

            if ($FoundEvent) {
                Write-Output "Writing new table"
                $UserTable[$P.TenantId] = $NewUserTable
            }


        } else {
            Write-Output "Unacceptable event type"

        }




    }

}
if ($FoundEvent) {
    Write-Output "Writing changes"
    Set-AutomationVariable -Name Users -Value ($UserTable | ConvertTo-Json -Compress).ToString()
}

