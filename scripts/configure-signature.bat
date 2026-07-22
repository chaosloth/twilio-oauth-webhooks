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

echo Creating signature key for webhook setting %WEBHOOK_SETTING_SID%...

:: Step 1: Create a new signature key
powershell -NoProfile -Command ^
  "$cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('%TWILIO_API_KEY_SID%:%TWILIO_API_KEY_SECRET%'));" ^
  "$headers = @{ 'Content-Type' = 'application/json'; 'Authorization' = \"Basic $cred\" };" ^
  "try {" ^
  "  $r = Invoke-RestMethod -Uri 'https://preview.twilio.com/Webhooks/Settings/%WEBHOOK_SETTING_SID%/SignatureKeys' -Method Post -Headers $headers -Body '{}';" ^
  "  if (-not $r.sid -or -not $r.secret) { Write-Error 'Could not extract key SID or secret from response'; exit 1 }" ^
  "  $r.sid | Out-File -FilePath '%TEMP%\twilio_sig_sid.txt' -NoNewline -Encoding ascii;" ^
  "  $r.secret | Out-File -FilePath '%TEMP%\twilio_sig_secret.txt' -NoNewline -Encoding ascii" ^
  "} catch {" ^
  "  $code = $_.Exception.Response.StatusCode.value__;" ^
  "  Write-Host \"Error: Expected 201, got $code\";" ^
  "  Write-Host $_.ErrorDetails.Message;" ^
  "  exit 1" ^
  "}"

if errorlevel 1 exit /b 1

set /p KEY_SID=<"%TEMP%\twilio_sig_sid.txt"
set /p KEY_SECRET=<"%TEMP%\twilio_sig_secret.txt"
del "%TEMP%\twilio_sig_sid.txt" 2>nul
del "%TEMP%\twilio_sig_secret.txt" 2>nul

if "%KEY_SID%"=="" (
    echo Error: Could not extract key SID from response.
    exit /b 1
)
if "%KEY_SECRET%"=="" (
    echo Error: Could not extract key secret from response.
    exit /b 1
)

echo Signature key created: %KEY_SID%

:: Step 2: Activate the signature key on the webhook setting
echo Activating signature validation on webhook setting %WEBHOOK_SETTING_SID%...

powershell -NoProfile -Command ^
  "$cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('%TWILIO_API_KEY_SID%:%TWILIO_API_KEY_SECRET%'));" ^
  "$headers = @{ 'Content-Type' = 'application/json'; 'Authorization' = \"Basic $cred\" };" ^
  "$body = '{\"signature\": {\"type\": \"shared_key\", \"shared_key\": {\"key_sid\": \"%KEY_SID%\"}, \"enabled\": true}}';" ^
  "try {" ^
  "  Invoke-RestMethod -Uri 'https://preview.twilio.com/Webhooks/Settings/%WEBHOOK_SETTING_SID%' -Method Patch -Headers $headers -Body $body | Out-Null" ^
  "} catch {" ^
  "  $code = $_.Exception.Response.StatusCode.value__;" ^
  "  Write-Host \"Error: Expected 200, got $code\";" ^
  "  Write-Host $_.ErrorDetails.Message;" ^
  "  exit 1" ^
  "}"

if errorlevel 1 exit /b 1

:: Update .env with SIGNATURE_KEY_SID
findstr /v "^SIGNATURE_KEY_SID=" "%ENV_FILE%" > "%ENV_FILE%.tmp"
echo SIGNATURE_KEY_SID=%KEY_SID%>> "%ENV_FILE%.tmp"
move /y "%ENV_FILE%.tmp" "%ENV_FILE%" > nul

:: Update .env with SIGNATURE_KEY_SECRET
findstr /v "^SIGNATURE_KEY_SECRET=" "%ENV_FILE%" > "%ENV_FILE%.tmp"
echo SIGNATURE_KEY_SECRET=%KEY_SECRET%>> "%ENV_FILE%.tmp"
move /y "%ENV_FILE%.tmp" "%ENV_FILE%" > nul

echo Signature validation configured successfully.
echo SIGNATURE_KEY_SID saved to .env: %KEY_SID%
echo SIGNATURE_KEY_SECRET saved to .env
echo.
echo IMPORTANT: Use the SIGNATURE_KEY_SECRET to validate webhook signatures on your server.
endlocal
