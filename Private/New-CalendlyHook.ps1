function New-CalendlyHook {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$True)]
    [string]$RunbookUri, # This is the uri for the azure automation runbook
    [Parameter()]
    [string]$APICurrentUserUri = "https://api.calendly.com/users/me",
    [string]$APIWebhookCreate = "https://api.calendly.com/webhook_subscriptions",
    [string]$APIWebhookList = "https://api.calendly.com/webhook_subscriptions",
    [Parameter(Mandatory=$True)]
    [string]$APIKey
  )

  $ReqParams = @{
    "Headers" = @{
      "Authorization" = $APIKey
    }
  }

  Write-Verbose "Will now try to authenticate with Calendly API."

  
  $result = Invoke-WebRequest @ReqParams -Method "GET" -Uri $APICurrentUserUri
  
  if ($result.StatusCode -ne 200) {
    Write-Error "Could not authenticate with callendly api" -TargetObject $result
  }

  $result = Invoke-RestMethod @ReqParams -Uri $APICurrentUserUri
  $bodyParams = @{
    "organization" = $result.resource.current_organization
    "scope" = "Organization"
  }

  Write-Verbose "Fetching existing webhooks.."
  $webhookLists = Invoke-RestMethod @ReqParams -Method "GET" -Uri $APIWebhookList -Body $bodyParams

  if ($webhookLists.collection.Length -ge 1) {
    Write-Output ("Seems like you already have " + $webhookLists.collection.Length.ToString() + " webhooks on Calendly, you should review them")
  }

  Write-Verbose "Now creating new webhook"
  
  $createBody = @{
    "url" = $RunbookUri
    "events" = @("invitee.created", "invitee.cancelled")
    "organization" = ($result.resource.current_organization)
    "scope" = "organization"
  }

  $r = Invoke-WebRequest @ReqParams -Method "POST" -Uri $APIWebhookCreate -Body $createBody

  if ($r.StatusCode -ne 200) {
    Write-Error "Could not create webhook, something happened."
    Write-Error $r
    return $r
  }

  return $r

}