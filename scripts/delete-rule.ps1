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

$WebhookRuleSid = [Environment]::GetEnvironmentVariable("WEBHOOK_RULE_SID")
if ([string]::IsNullOrEmpty($WebhookRuleSid)) {
    Write-Error "Error: WEBHOOK_RULE_SID not set. Nothing to delete."
    exit 1
}

Write-Host "Deleting webhook rule ${WebhookRuleSid}..."

$ApiKeySid = [Environment]::GetEnvironmentVariable("TWILIO_API_KEY_SID")
$ApiKeySecret = [Environment]::GetEnvironmentVariable("TWILIO_API_KEY_SECRET")
$Base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${ApiKeySid}:${ApiKeySecret}"))

$Headers = @{
    "Authorization" = "Basic $Base64Auth"
}

try {
    Invoke-RestMethod `
        -Uri "https://preview.twilio.com/Webhooks/Rules/${WebhookRuleSid}" `
        -Method Delete `
        -Headers $Headers

    # Clear the rule SID from .env
    $EnvContent = Get-Content $EnvFile -Raw
    $EnvContent = $EnvContent -replace '(?m)^WEBHOOK_RULE_SID=.*', 'WEBHOOK_RULE_SID='
    Set-Content -Path $EnvFile -Value $EnvContent.TrimEnd() -NoNewline

    Write-Host "Webhook rule deleted. WEBHOOK_RULE_SID cleared from .env."
    Write-Host "Changes take up to 5 minutes to take effect."
}
catch {
    $StatusCode = $_.Exception.Response.StatusCode.value__
    Write-Error "Error: Expected 204, got ${StatusCode}"
    Write-Error $_.ErrorDetails.Message
    exit 1
}
