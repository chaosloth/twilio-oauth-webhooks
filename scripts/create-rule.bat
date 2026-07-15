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

:: Default to catch-all filter, can be overridden via arguments
set "FILTER=*"
set "PRIORITY=100"
set "TRAFFIC_PERCENTAGE=100"

if not "%~1"=="" set "FILTER=%~1"
if not "%~2"=="" set "PRIORITY=%~2"
if not "%~3"=="" set "TRAFFIC_PERCENTAGE=%~3"

echo Creating webhook rule...
echo   Setting: %WEBHOOK_SETTING_SID%
echo   Filter: %FILTER%
echo   Priority: %PRIORITY%
echo   Traffic: %TRAFFIC_PERCENTAGE%%%

powershell -NoProfile -Command ^
  "$cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('%TWILIO_API_KEY_SID%:%TWILIO_API_KEY_SECRET%'));" ^
  "$headers = @{ 'Content-Type' = 'application/json'; 'Authorization' = \"Basic $cred\" };" ^
  "$body = '{\"webhook_setting_sid\": \"%WEBHOOK_SETTING_SID%\", \"filter\": \"%FILTER%\", \"priority\": %PRIORITY%, \"traffic_percentage\": %TRAFFIC_PERCENTAGE%}';" ^
  "try {" ^
  "  $r = Invoke-RestMethod -Uri 'https://preview.twilio.com/Webhooks/Rules' -Method Post -Headers $headers -Body $body;" ^
  "  if (-not $r.sid) { Write-Error 'Could not extract Rule SID from response'; exit 1 }" ^
  "  $r.sid | Out-File -FilePath '%TEMP%\twilio_rule_sid.txt' -NoNewline -Encoding ascii" ^
  "} catch {" ^
  "  $code = $_.Exception.Response.StatusCode.value__;" ^
  "  Write-Host \"Error: Expected 201, got $code\";" ^
  "  Write-Host $_.ErrorDetails.Message;" ^
  "  exit 1" ^
  "}"

if errorlevel 1 exit /b 1

set /p RULE_SID=<"%TEMP%\twilio_rule_sid.txt"
del "%TEMP%\twilio_rule_sid.txt" 2>nul

if "%RULE_SID%"=="" (
    echo Error: Could not extract Rule SID from response.
    exit /b 1
)

:: Save rule SID to .env
findstr /v "^WEBHOOK_RULE_SID=" "%ENV_FILE%" > "%ENV_FILE%.tmp"
echo WEBHOOK_RULE_SID=%RULE_SID%>> "%ENV_FILE%.tmp"
move /y "%ENV_FILE%.tmp" "%ENV_FILE%" > nul

echo Webhook rule created: %RULE_SID%
echo WEBHOOK_RULE_SID saved to .env
echo Changes take up to 5 minutes to take effect.
endlocal
