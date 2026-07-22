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

$ApiKeySid = [Environment]::GetEnvironmentVariable("TWILIO_API_KEY_SID")
$ApiKeySecret = [Environment]::GetEnvironmentVariable("TWILIO_API_KEY_SECRET")
$Base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${ApiKeySid}:${ApiKeySecret}"))

$Headers = @{
    "Content-Type"  = "application/json"
    "Authorization" = "Basic $Base64Auth"
}

# Step 1: Delete webhook rule (must be removed before the setting can be deleted)
$WebhookRuleSid = [Environment]::GetEnvironmentVariable("WEBHOOK_RULE_SID")
if (-not [string]::IsNullOrEmpty($WebhookRuleSid)) {
    Write-Host "Deleting webhook rule ${WebhookRuleSid}..."
    try {
        Invoke-RestMethod `
            -Uri "https://preview.twilio.com/Webhooks/Rules/${WebhookRuleSid}" `
            -Method Delete `
            -Headers $Headers | Out-Null
        Write-Host "Rule deleted."
    }
    catch {
        $StatusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "Warning: Rule delete returned ${StatusCode} (expected 204)"
    }

    $EnvContent = Get-Content $EnvFile -Raw
    $EnvContent = $EnvContent -replace '(?m)^WEBHOOK_RULE_SID=.*', 'WEBHOOK_RULE_SID='
    Set-Content -Path $EnvFile -Value $EnvContent.TrimEnd() -NoNewline
}
else {
    Write-Host "No WEBHOOK_RULE_SID set, skipping rule deletion."
}

# Step 2: Delete webhook setting (also removes any signature keys associated with it)
$WebhookSettingSid = [Environment]::GetEnvironmentVariable("WEBHOOK_SETTING_SID")
if (-not [string]::IsNullOrEmpty($WebhookSettingSid)) {
    Write-Host "Deleting webhook setting ${WebhookSettingSid}..."
    try {
        Invoke-RestMethod `
            -Uri "https://preview.twilio.com/Webhooks/Settings/${WebhookSettingSid}" `
            -Method Delete `
            -Headers $Headers | Out-Null
        Write-Host "Setting deleted."
    }
    catch {
        $StatusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "Warning: Setting delete returned ${StatusCode} (expected 204)"
    }

    $EnvContent = Get-Content $EnvFile -Raw
    $EnvContent = $EnvContent -replace '(?m)^WEBHOOK_SETTING_SID=.*', 'WEBHOOK_SETTING_SID='
    Set-Content -Path $EnvFile -Value $EnvContent.TrimEnd() -NoNewline
}
else {
    Write-Host "No WEBHOOK_SETTING_SID set, skipping setting deletion."
}

# Step 3: Clear signature key values from .env
$SignatureKeySid = [Environment]::GetEnvironmentVariable("SIGNATURE_KEY_SID")
if (-not [string]::IsNullOrEmpty($SignatureKeySid)) {
    $EnvContent = Get-Content $EnvFile -Raw
    $EnvContent = $EnvContent -replace '(?m)^SIGNATURE_KEY_SID=.*', 'SIGNATURE_KEY_SID='
    $EnvContent = $EnvContent -replace '(?m)^SIGNATURE_KEY_SECRET=.*', 'SIGNATURE_KEY_SECRET='
    Set-Content -Path $EnvFile -Value $EnvContent.TrimEnd() -NoNewline
    Write-Host "Signature key values cleared from .env."
}

Write-Host "Teardown complete. OAuth and PSK signature validation will no longer be applied to webhooks."
