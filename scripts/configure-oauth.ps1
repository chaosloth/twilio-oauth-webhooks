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

Write-Host "Configuring OAuth 2.0 for webhook setting ${WebhookSettingSid}..."

$OAuthTokenUrl = [Environment]::GetEnvironmentVariable("OAUTH_TOKEN_URL")
$OAuthClientId = [Environment]::GetEnvironmentVariable("OAUTH_CLIENT_ID")
$OAuthClientSecret = [Environment]::GetEnvironmentVariable("OAUTH_CLIENT_SECRET")
$OAuthScope = [Environment]::GetEnvironmentVariable("OAUTH_SCOPE")
$OAuthAudience = [Environment]::GetEnvironmentVariable("OAUTH_AUDIENCE")

$OAuth2Config = @{
    token_url     = $OAuthTokenUrl
    client_id     = $OAuthClientId
    client_secret = $OAuthClientSecret
}

if (-not [string]::IsNullOrEmpty($OAuthScope)) {
    $OAuth2Config["scope"] = $OAuthScope
}
if (-not [string]::IsNullOrEmpty($OAuthAudience)) {
    $OAuth2Config["audience"] = $OAuthAudience
}

$Body = @{
    auth = @{
        enabled = $true
        type    = "oauth2"
        oauth2  = $OAuth2Config
    }
} | ConvertTo-Json -Depth 4

$ApiKeySid = [Environment]::GetEnvironmentVariable("TWILIO_API_KEY_SID")
$ApiKeySecret = [Environment]::GetEnvironmentVariable("TWILIO_API_KEY_SECRET")
$Base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${ApiKeySid}:${ApiKeySecret}"))

$Headers = @{
    "Content-Type"  = "application/json"
    "Authorization" = "Basic $Base64Auth"
}

try {
    $Response = Invoke-RestMethod `
        -Uri "https://preview.twilio.com/Webhooks/Settings/${WebhookSettingSid}" `
        -Method Patch `
        -Headers $Headers `
        -Body $Body

    Write-Host "OAuth 2.0 configured successfully."
}
catch {
    $StatusCode = $_.Exception.Response.StatusCode.value__
    Write-Error "Error: Expected 200, got ${StatusCode}"
    Write-Error $_.ErrorDetails.Message
    exit 1
}
