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

if "%TWILIO_API_KEY_SID%"=="" (
    echo Error: TWILIO_API_KEY_SID not set in .env.
    exit /b 1
)

echo Creating webhook setting...

powershell -NoProfile -Command ^
  "$cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('%TWILIO_API_KEY_SID%:%TWILIO_API_KEY_SECRET%'));" ^
  "$headers = @{ 'Content-Type' = 'application/json'; 'Authorization' = \"Basic $cred\" };" ^
  "$body = '{\"name\": \"Default Webhook Settings\"}';" ^
  "try {" ^
  "  $r = Invoke-RestMethod -Uri 'https://preview.twilio.com/Webhooks/Settings' -Method Post -Headers $headers -Body $body;" ^
  "  if (-not $r.sid) { Write-Error 'Could not extract SID from response'; exit 1 }" ^
  "  $r.sid | Out-File -FilePath '%TEMP%\twilio_sid.txt' -NoNewline -Encoding ascii" ^
  "} catch {" ^
  "  $code = $_.Exception.Response.StatusCode.value__;" ^
  "  Write-Host \"Error: Expected 201, got $code\";" ^
  "  Write-Host $_.ErrorDetails.Message;" ^
  "  exit 1" ^
  "}"

if errorlevel 1 exit /b 1

set /p SID=<"%TEMP%\twilio_sid.txt"
del "%TEMP%\twilio_sid.txt" 2>nul

if "%SID%"=="" (
    echo Error: Could not extract SID from response.
    exit /b 1
)

:: Update .env with the new SID
findstr /v "^WEBHOOK_SETTING_SID=" "%ENV_FILE%" > "%ENV_FILE%.tmp"
echo WEBHOOK_SETTING_SID=%SID%>> "%ENV_FILE%.tmp"
move /y "%ENV_FILE%.tmp" "%ENV_FILE%" > nul

echo Webhook setting created: %SID%
echo WEBHOOK_SETTING_SID saved to .env
endlocal
