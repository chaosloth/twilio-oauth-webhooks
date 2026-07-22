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

Write-Host "Creating signature key for webhook setting ${WebhookSettingSid}..."

$ApiKeySid = [Environment]::GetEnvironmentVariable("TWILIO_API_KEY_SID")
$ApiKeySecret = [Environment]::GetEnvironmentVariable("TWILIO_API_KEY_SECRET")
$Base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${ApiKeySid}:${ApiKeySecret}"))

$Headers = @{
    "Content-Type"  = "application/json"
    "Authorization" = "Basic $Base64Auth"
}

# Step 1: Create a new signature key
try {
    $Response = Invoke-RestMethod `
        -Uri "https://preview.twilio.com/Webhooks/Settings/${WebhookSettingSid}/SignatureKeys" `
        -Method Post `
        -Headers $Headers `
        -Body "{}"

    $KeySid = $Response.sid
    $KeySecret = $Response.secret

    if ([string]::IsNullOrEmpty($KeySid) -or [string]::IsNullOrEmpty($KeySecret)) {
        Write-Error "Error: Could not extract key SID or secret from response"
        Write-Host ($Response | ConvertTo-Json -Depth 4)
        exit 1
    }

    Write-Host "Signature key created: ${KeySid}"
}
catch {
    $StatusCode = $_.Exception.Response.StatusCode.value__
    Write-Error "Error: Expected 201, got ${StatusCode}"
    Write-Error $_.ErrorDetails.Message
    exit 1
}

# Step 2: Activate the signature key on the webhook setting
Write-Host "Activating signature validation on webhook setting ${WebhookSettingSid}..."

$Body = @{
    signature = @{
        type       = "shared_key"
        shared_key = @{
            key_sid = $KeySid
        }
        enabled    = $true
    }
} | ConvertTo-Json -Depth 4

try {
    $Response = Invoke-RestMethod `
        -Uri "https://preview.twilio.com/Webhooks/Settings/${WebhookSettingSid}" `
        -Method Patch `
        -Headers $Headers `
        -Body $Body

    # Save SIGNATURE_KEY_SID to .env
    $EnvContent = Get-Content $EnvFile -Raw
    if ($EnvContent -match '(?m)^SIGNATURE_KEY_SID=') {
        $EnvContent = $EnvContent -replace '(?m)^SIGNATURE_KEY_SID=.*', "SIGNATURE_KEY_SID=$KeySid"
    }
    else {
        $EnvContent = $EnvContent.TrimEnd() + "`nSIGNATURE_KEY_SID=$KeySid"
    }

    # Save SIGNATURE_KEY_SECRET to .env
    if ($EnvContent -match '(?m)^SIGNATURE_KEY_SECRET=') {
        $EnvContent = $EnvContent -replace '(?m)^SIGNATURE_KEY_SECRET=.*', "SIGNATURE_KEY_SECRET=$KeySecret"
    }
    else {
        $EnvContent = $EnvContent.TrimEnd() + "`nSIGNATURE_KEY_SECRET=$KeySecret"
    }

    Set-Content -Path $EnvFile -Value $EnvContent.TrimEnd() -NoNewline

    Write-Host "Signature validation configured successfully."
    Write-Host "SIGNATURE_KEY_SID saved to .env: ${KeySid}"
    Write-Host "SIGNATURE_KEY_SECRET saved to .env"
    Write-Host ""
    Write-Host "IMPORTANT: Use the SIGNATURE_KEY_SECRET to validate webhook signatures on your server."
}
catch {
    $StatusCode = $_.Exception.Response.StatusCode.value__
    Write-Error "Error: Expected 200, got ${StatusCode}"
    Write-Error $_.ErrorDetails.Message
    exit 1
}
