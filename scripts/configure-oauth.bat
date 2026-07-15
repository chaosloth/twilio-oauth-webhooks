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

if "%WEBHOOK_SETTING_SID%"=="" (
    echo Error: WEBHOOK_SETTING_SID not set. Run create-setting.bat first.
    exit /b 1
)

echo Configuring OAuth 2.0 for webhook setting %WEBHOOK_SETTING_SID%...

set "OPTIONAL_FIELDS="
if not "%OAUTH_SCOPE%"=="" (
    set "OPTIONAL_FIELDS=, \"scope\": \"%OAUTH_SCOPE%\""
)
if not "%OAUTH_AUDIENCE%"=="" (
    set "OPTIONAL_FIELDS=!OPTIONAL_FIELDS!, \"audience\": \"%OAUTH_AUDIENCE%\""
)

powershell -NoProfile -Command ^
  "$cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('%TWILIO_API_KEY_SID%:%TWILIO_API_KEY_SECRET%'));" ^
  "$headers = @{ 'Content-Type' = 'application/json'; 'Authorization' = \"Basic $cred\" };" ^
  "$body = '{\"auth\": {\"enabled\": true, \"type\": \"oauth2\", \"oauth2\": {\"token_url\": \"%OAUTH_TOKEN_URL%\", \"client_id\": \"%OAUTH_CLIENT_ID%\", \"client_secret\": \"%OAUTH_CLIENT_SECRET%\"%OPTIONAL_FIELDS%}}}';" ^
  "try {" ^
  "  Invoke-RestMethod -Uri 'https://preview.twilio.com/Webhooks/Settings/%WEBHOOK_SETTING_SID%' -Method Patch -Headers $headers -Body $body | Out-Null" ^
  "} catch {" ^
  "  $code = $_.Exception.Response.StatusCode.value__;" ^
  "  Write-Host \"Error: Expected 200, got $code\";" ^
  "  Write-Host $_.ErrorDetails.Message;" ^
  "  exit 1" ^
  "}"

if errorlevel 1 exit /b 1

echo OAuth 2.0 configured successfully.
endlocal
