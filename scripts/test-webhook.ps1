param(
    [string]$Method = "POST"
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

$WebhookUrl = [Environment]::GetEnvironmentVariable("WEBHOOK_URL")
if ([string]::IsNullOrEmpty($WebhookUrl)) {
    Write-Error "Error: WEBHOOK_URL not set in .env."
    exit 1
}

Write-Host "Testing webhook setting ${WebhookSettingSid} against ${WebhookUrl} (${Method})..."

$Body = @{
    method = $Method
    url    = $WebhookUrl
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
        -Uri "https://preview.twilio.com/Webhooks/Settings/${WebhookSettingSid}/Test" `
        -Method Post `
        -Headers $Headers `
        -Body $Body

    Write-Host "Test successful! Your webhook endpoint accepted the OAuth-authenticated request."
}
catch {
    $StatusCode = $_.Exception.Response.StatusCode.value__
    Write-Error "Error: Expected 200, got ${StatusCode}"
    Write-Error $_.ErrorDetails.Message
    Write-Host "Check the Twilio Console Debugger for error details."
    exit 1
}
