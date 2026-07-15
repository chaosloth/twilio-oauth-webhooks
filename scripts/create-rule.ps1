param(
    [string]$Filter = "*",
    [int]$Priority = 100,
    [int]$TrafficPercentage = 100
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path (Split-Path -Parent $ScriptDir) ".env"

if (-not (Test-Path $EnvFile)) {
    Write-Error "Error: .env file not found. Copy .env.example to .env and fill in your values."
    exit 1
}

# Parse .env file
Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim())
    }
}

$WebhookSettingSid = [Environment]::GetEnvironmentVariable("WEBHOOK_SETTING_SID")
if ([string]::IsNullOrEmpty($WebhookSettingSid)) {
    Write-Error "Error: WEBHOOK_SETTING_SID not set. Run create-setting.ps1 first."
    exit 1
}

Write-Host "Creating webhook rule..."
Write-Host "  Setting: ${WebhookSettingSid}"
Write-Host "  Filter: ${Filter}"
Write-Host "  Priority: ${Priority}"
Write-Host "  Traffic: ${TrafficPercentage}%"

$Body = @{
    webhook_setting_sid = $WebhookSettingSid
    filter              = $Filter
    priority            = $Priority
    traffic_percentage  = $TrafficPercentage
} | ConvertTo-Json

$ApiKeySid = [Environment]::GetEnvironmentVariable("TWILIO_API_KEY_SID")
$ApiKeySecret = [Environment]::GetEnvironmentVariable("TWILIO_API_KEY_SECRET")
$Base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${ApiKeySid}:${ApiKeySecret}"))

$Headers = @{
    "Content-Type"  = "application/json"
    "Authorization" = "Basic $Base64Auth"
}

try {
    $Response = Invoke-RestMethod `
        -Uri "https://preview.twilio.com/Webhooks/Rules" `
        -Method Post `
        -Headers $Headers `
        -Body $Body

    $RuleSid = $Response.sid

    if ([string]::IsNullOrEmpty($RuleSid)) {
        Write-Error "Error: Could not extract Rule SID from response"
        Write-Host ($Response | ConvertTo-Json -Depth 4)
        exit 1
    }

    # Save rule SID to .env
    $EnvContent = Get-Content $EnvFile -Raw
    if ($EnvContent -match '(?m)^WEBHOOK_RULE_SID=') {
        $EnvContent = $EnvContent -replace '(?m)^WEBHOOK_RULE_SID=.*', "WEBHOOK_RULE_SID=$RuleSid"
        Set-Content -Path $EnvFile -Value $EnvContent.TrimEnd() -NoNewline
    }
    else {
        Add-Content -Path $EnvFile -Value "`nWEBHOOK_RULE_SID=$RuleSid"
    }

    Write-Host "Webhook rule created: ${RuleSid}"
    Write-Host "WEBHOOK_RULE_SID saved to .env"
    Write-Host "Changes take up to 5 minutes to take effect."
}
catch {
    $StatusCode = $_.Exception.Response.StatusCode.value__
    Write-Error "Error: Expected 201, got ${StatusCode}"
    Write-Error $_.ErrorDetails.Message
    exit 1
}
