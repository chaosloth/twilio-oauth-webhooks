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

Write-Host "Creating webhook setting..."

$Body = @{
    name = "Default Webhook Settings"
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
        -Uri "https://preview.twilio.com/Webhooks/Settings" `
        -Method Post `
        -Headers $Headers `
        -Body $Body

    $Sid = $Response.sid

    if ([string]::IsNullOrEmpty($Sid)) {
        Write-Error "Error: Could not extract SID from response"
        Write-Host ($Response | ConvertTo-Json -Depth 4)
        exit 1
    }

    # Save setting SID to .env
    $EnvContent = Get-Content $EnvFile -Raw
    if ($EnvContent -match '(?m)^WEBHOOK_SETTING_SID=') {
        $EnvContent = $EnvContent -replace '(?m)^WEBHOOK_SETTING_SID=.*', "WEBHOOK_SETTING_SID=$Sid"
        Set-Content -Path $EnvFile -Value $EnvContent.TrimEnd() -NoNewline
    }
    else {
        Add-Content -Path $EnvFile -Value "`nWEBHOOK_SETTING_SID=$Sid"
    }

    Write-Host "Webhook setting created: ${Sid}"
    Write-Host "WEBHOOK_SETTING_SID saved to .env"
}
catch {
    $StatusCode = $_.Exception.Response.StatusCode.value__
    Write-Error "Error: Expected 201, got ${StatusCode}"
    Write-Error $_.ErrorDetails.Message
    exit 1
}
