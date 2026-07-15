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

if "%WEBHOOK_URL%"=="" (
    echo Error: WEBHOOK_URL not set in .env.
    exit /b 1
)

set "METHOD=POST"
if not "%~1"=="" set "METHOD=%~1"

echo Testing webhook setting %WEBHOOK_SETTING_SID% against %WEBHOOK_URL% (%METHOD%)...

powershell -NoProfile -Command ^
  "$cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('%TWILIO_API_KEY_SID%:%TWILIO_API_KEY_SECRET%'));" ^
  "$headers = @{ 'Content-Type' = 'application/json'; 'Authorization' = \"Basic $cred\" };" ^
  "$body = '{\"method\": \"%METHOD%\", \"url\": \"%WEBHOOK_URL%\"}';" ^
  "try {" ^
  "  Invoke-RestMethod -Uri 'https://preview.twilio.com/Webhooks/Settings/%WEBHOOK_SETTING_SID%/Test' -Method Post -Headers $headers -Body $body | Out-Null" ^
  "} catch {" ^
  "  $code = $_.Exception.Response.StatusCode.value__;" ^
  "  Write-Host \"Error: Expected 200, got $code\";" ^
  "  Write-Host $_.ErrorDetails.Message;" ^
  "  Write-Host 'Check the Twilio Console Debugger for error details.';" ^
  "  exit 1" ^
  "}"

if errorlevel 1 exit /b 1

echo Test successful! Your webhook endpoint accepted the OAuth-authenticated request.
endlocal
