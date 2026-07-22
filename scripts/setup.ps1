$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path (Split-Path -Parent $ScriptDir) ".env"

Write-Host "=== Twilio OAuth Webhook Setup ==="
Write-Host ""

# Step 1: Create API Key (if not already set)
$ApiKeySid = ""
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim())
        }
    }
    $ApiKeySid = [Environment]::GetEnvironmentVariable("TWILIO_API_KEY_SID")
}

if ([string]::IsNullOrEmpty($ApiKeySid) -or $ApiKeySid -eq "SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx") {
    Write-Host "Step 1: Create a Twilio API Key"
    Write-Host "  You can create one in the Console or use this script."
    Write-Host "  Requires TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN_SECRET in .env."
    $reply = Read-Host "  Create API Key now? (y/n)"
    if ($reply -match '^[Yy]') {
        & "$ScriptDir\create-api-key.ps1"
        # Re-read .env
        Get-Content $EnvFile | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
                [Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim())
            }
        }
    }
    Write-Host ""
}
else {
    Write-Host "Step 1: API Key already configured ($ApiKeySid)"
    Write-Host ""
}

# Step 2: Create setting
Write-Host "Step 2: Creating webhook setting..."
& "$ScriptDir\create-setting.ps1"
Write-Host ""

# Step 3: Configure OAuth
$reply = Read-Host "Step 3: Configure OAuth 2.0? (y/n)"
if ($reply -match '^[Yy]') {
    & "$ScriptDir\configure-oauth.ps1"
}
Write-Host ""

# Step 4: Configure PSK Signature Validation (optional)
Write-Host "Step 4: Configure Pre-Shared Key (PSK) Signature Validation"
Write-Host "  This creates a dedicated signing key for X-Twilio-Signature (instead of the auth token)."
Write-Host "  Enables key rotation without downtime."
$reply = Read-Host "  Configure PSK signature? (y/n)"
if ($reply -match '^[Yy]') {
    & "$ScriptDir\configure-signature.ps1"
}
Write-Host ""

# Step 5: Test
Write-Host "Step 5: Test webhook endpoint"
Write-Host "  This requires your webhook server AND ngrok tunnel to be running."
Write-Host "  Start one with:"
Write-Host "    TypeScript: npm --prefix servers/typescript run dev"
Write-Host "    Python:     python3 servers/python/server.py"
Write-Host "    Go:         ./servers/golang/golang-server"
Write-Host "  Skip if not ready - you can test later with: .\scripts\test-webhook.ps1"
$reply = Read-Host "  Test now? (y/n)"
if ($reply -match '^[Yy]') {
    & "$ScriptDir\test-webhook.ps1"
}

# Step 6: Create webhook rule to apply setting
Write-Host ""
Write-Host "Step 6: Create a Webhook Rule to apply this setting to your webhooks."
Write-Host "  Default: catch-all filter '*' (applies to all webhooks)"
Write-Host "  You can also run: .\scripts\create-rule.ps1 -Filter 'https://your-domain.com/*'"
$reply = Read-Host "  Create catch-all rule now? (y/n)"
if ($reply -match '^[Yy]') {
    & "$ScriptDir\create-rule.ps1"
}

Write-Host ""
Write-Host "=== Setup complete ==="
Write-Host "Changes take up to 5 minutes to take effect."
