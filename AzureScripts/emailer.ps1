$Enabled = Get-AutomationVariable -Name 'emailerEnabled'

$EmailTemplate = Get-AutomationVariable -Name 'EmailTemplateBase'

$Creds = Get-AutomationPSCredential -Name 'azautomation'

$EmailParamsBase = @{
    Bcc = "alecompte@natrix.info"
    Subject = "[IMPORTANT] Authentification Multifacteur - Multifactor Authentication"
    From = "Natrix Technologies <automation@natrix.ca>"
    UseSsl = $True
    Port = 587
    SmtpServer = "smtp.office365.com"
    BodyAsHtml = $True
    Credential = $Creds
}


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

function Send-Email {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]$DisplayName,
        [String]$Email,
        [String]$CutOffDate
    )

    $EmailString = ($EmailTemplate.PSObject.Copy()).Replace('{{$DisplayName}}', $DisplayName).Replace('{{$CutoffDate}}', $CutOffDate)

    Send-MailMessage @EmailParamsBase -To $Email -Body $EmailString -Encoding UTF8
    Start-Sleep -Seconds 5

}


$UserTable = Get-AutomationVariable -Name 'Users'
$Partners = (ConvertFrom-Json -InputObject (Get-AutomationVariable -Name 'Partners'))

$UserTable = ConvertFrom-JsonToHashtable -InputObject $UserTable

$IsWeekend = $False
$Day = (Get-Date).DayOfWeek
if (($Day -eq "Saturday") -or ($Day -eq "Sunday")) {
    $IsWeekend = $True
}


$UserTable.GetEnumerator() | Foreach-Object {

    $Tenant = $_

    foreach ($u in $Tenant.Value) {

        if (!$IsWeekend -and !$u.Deleted -and !$u.MFAEnabled -and !$u.MFAExempt -and !$u.IsScheduled -and ($Partners | Where {($_.TenantId -eq $Tenant.Key) -and ($_.Enabled -and $_.MFAEnabled -and $_.Managed)})) {
            $Email = $u.Email
            $DisplayName = $u.DisplayName
            Write-Output "Sent email to $DisplayName with email $Email"
            
            if ($Enabled) {
                $today =  (Get-Date -UFormat "%d/%m/%Y").ToString()
                $u.ContactAttempts = $u.ContactAttempts + ",$today"

                Send-Email -DisplayName $DisplayName -Email $Email -CutOffDate $u.CutOffDate
            } else {
                
                Write-Output "Would email $DisplayName with $Email"


            }


        }



    }


}

Set-AutomationVariable -Name Users -Value ($UserTable | ConvertTo-Json | Out-String)
