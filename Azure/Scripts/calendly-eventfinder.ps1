#v:1.0.0
Param(
    [Parameter(Mandatory=$True)]
    [object]$WebhookData
)

$apiToken = Get-AutomationVariable -Name 'calendlyApiKey'
$tempEvents = Get-AutomationVaraible -Name 'tempCalendlyHits'

if ($tempEvents -eq "emtpy") {
    $tempEvents = @("notanevent")
} else {
    $tempEvents = ConvertFrom-Json $tempEvents
}

if ($WebhookData) {

    $eventData = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)

    if (($eventData.event -eq "invitee.created") -or ($eventData.event -eq "invitee.cancelled")) {


        $Headers = @{
            "authorization" = $apiToken
            "Content-Type" = 'application/json'
        }

        $response = Invoke-RestMethod -Uri $eventData.payload.event -Method GET -Headers $Headers -UseBasicParsing

        $tempEvents += $response




    }

}

Set-AutomationVariable -Name "tempCalendlyHits" -Value (ConvertFrom-Json $tempEvents | Out-String)