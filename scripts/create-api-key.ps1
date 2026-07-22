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

$AccountSid = [Environment]::GetEnvironmentVariable("TWILIO_ACCOUNT_SID")
$AuthToken = [Environment]::GetEnvironmentVariable("TWILIO_AUTH_TOKEN_SECRET")

if ([string]::IsNullOrEmpty($AccountSid)) {
    Write-Error "Error: TWILIO_ACCOUNT_SID not set in .env."
    exit 1
}

if ([string]::IsNullOrEmpty($AuthToken)) {
    Write-Error "Error: TWILIO_AUTH_TOKEN_SECRET not set in .env."
    exit 1
}

Write-Host "Creating Twilio Standard API Key..."

$Base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${AccountSid}:${AuthToken}"))

$Headers = @{
    "Authorization" = "Basic $Base64Auth"
}

$Body = @{
    AccountSid   = $AccountSid
    FriendlyName = "Twilio Webhooks API Key"
}

try {
    $Response = Invoke-RestMethod `
        -Uri "https://iam.twilio.com/v1/Keys" `
        -Method Post `
        -Headers $Headers `
        -Body $Body `
        -ContentType "application/x-www-form-urlencoded"

    $ApiKeySid = $Response.sid
    $ApiKeySecret = $Response.secret

    if ([string]::IsNullOrEmpty($ApiKeySid)) {
        Write-Error "Error: Could not extract SID from response"
        Write-Host ($Response | ConvertTo-Json -Depth 4)
        exit 1
    }

    if ([string]::IsNullOrEmpty($ApiKeySecret)) {
        Write-Error "Error: Could not extract secret from response"
        Write-Host ($Response | ConvertTo-Json -Depth 4)
        exit 1
    }

    # Save API Key SID to .env
    $EnvContent = Get-Content $EnvFile -Raw
    if ($EnvContent -match '(?m)^TWILIO_API_KEY_SID=') {
        $EnvContent = $EnvContent -replace '(?m)^TWILIO_API_KEY_SID=.*', "TWILIO_API_KEY_SID=$ApiKeySid"
    }
    else {
        $EnvContent = $EnvContent.TrimEnd() + "`nTWILIO_API_KEY_SID=$ApiKeySid"
    }

    # Save API Key Secret to .env
    if ($EnvContent -match '(?m)^TWILIO_API_KEY_SECRET=') {
        $EnvContent = $EnvContent -replace '(?m)^TWILIO_API_KEY_SECRET=.*', "TWILIO_API_KEY_SECRET=$ApiKeySecret"
    }
    else {
        $EnvContent = $EnvContent.TrimEnd() + "`nTWILIO_API_KEY_SECRET=$ApiKeySecret"
    }

    Set-Content -Path $EnvFile -Value $EnvContent.TrimEnd() -NoNewline

    Write-Host "API Key created: ${ApiKeySid}"
    Write-Host "TWILIO_API_KEY_SID and TWILIO_API_KEY_SECRET saved to .env"
    Write-Host ""
    Write-Host "IMPORTANT: Store the API Key Secret securely - it cannot be retrieved again."
}
catch {
    $StatusCode = $_.Exception.Response.StatusCode.value__
    Write-Error "Error: Expected 201, got ${StatusCode}"
    Write-Error $_.ErrorDetails.Message
    exit 1
}
