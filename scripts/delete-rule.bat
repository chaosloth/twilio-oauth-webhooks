@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "ENV_FILE=%SCRIPT_DIR%..\.env"

if not exist "%ENV_FILE%" (
    echo Error: .env file not found. Copy .env.example to .env and fill in your values.
    exit /b 1
)

for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
    set "LINE=%%A"
    if not "!LINE:~0,1!"=="#" (
        set "%%A=%%B"
    )
)

if "%WEBHOOK_RULE_SID%"=="" (
    echo Error: WEBHOOK_RULE_SID not set. Nothing to delete.
    exit /b 1
)

echo Deleting webhook rule %WEBHOOK_RULE_SID%...

powershell -NoProfile -Command ^
  "$cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('%TWILIO_API_KEY_SID%:%TWILIO_API_KEY_SECRET%'));" ^
  "$headers = @{ 'Authorization' = \"Basic $cred\" };" ^
  "try {" ^
  "  Invoke-RestMethod -Uri 'https://preview.twilio.com/Webhooks/Rules/%WEBHOOK_RULE_SID%' -Method Delete -Headers $headers | Out-Null" ^
  "} catch {" ^
  "  $code = $_.Exception.Response.StatusCode.value__;" ^
  "  if ($code -ne 204 -and $code -ne 200) {" ^
  "    Write-Host \"Error: Expected 204, got $code\";" ^
  "    Write-Host $_.ErrorDetails.Message;" ^
  "    exit 1" ^
  "  }" ^
  "}"

if errorlevel 1 exit /b 1

:: Clear the rule SID from .env
findstr /v "^WEBHOOK_RULE_SID=" "%ENV_FILE%" > "%ENV_FILE%.tmp"
echo WEBHOOK_RULE_SID=>> "%ENV_FILE%.tmp"
move /y "%ENV_FILE%.tmp" "%ENV_FILE%" > nul

echo Webhook rule deleted. WEBHOOK_RULE_SID cleared from .env.
echo Changes take up to 5 minutes to take effect.
endlocal
