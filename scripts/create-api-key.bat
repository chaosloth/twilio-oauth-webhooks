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

if "%TWILIO_ACCOUNT_SID%"=="" (
    echo Error: TWILIO_ACCOUNT_SID not set in .env.
    exit /b 1
)

if "%TWILIO_AUTH_TOKEN_SECRET%"=="" (
    echo Error: TWILIO_AUTH_TOKEN_SECRET not set in .env.
    exit /b 1
)

echo Creating Twilio Standard API Key...

powershell -NoProfile -Command ^
  "$cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('%TWILIO_ACCOUNT_SID%:%TWILIO_AUTH_TOKEN_SECRET%'));" ^
  "$headers = @{ 'Authorization' = \"Basic $cred\" };" ^
  "$body = @{ AccountSid = '%TWILIO_ACCOUNT_SID%'; FriendlyName = 'Twilio Webhooks API Key' };" ^
  "try {" ^
  "  $r = Invoke-RestMethod -Uri 'https://iam.twilio.com/v1/Keys' -Method Post -Headers $headers -Body $body -ContentType 'application/x-www-form-urlencoded';" ^
  "  if (-not $r.sid) { Write-Error 'Could not extract SID from response'; exit 1 }" ^
  "  if (-not $r.secret) { Write-Error 'Could not extract secret from response'; exit 1 }" ^
  "  $r.sid | Out-File -FilePath '%TEMP%\twilio_api_key_sid.txt' -NoNewline -Encoding ascii;" ^
  "  $r.secret | Out-File -FilePath '%TEMP%\twilio_api_key_secret.txt' -NoNewline -Encoding ascii" ^
  "} catch {" ^
  "  $code = $_.Exception.Response.StatusCode.value__;" ^
  "  Write-Host \"Error: Expected 201, got $code\";" ^
  "  Write-Host $_.ErrorDetails.Message;" ^
  "  exit 1" ^
  "}"

if errorlevel 1 exit /b 1

set /p API_KEY_SID=<"%TEMP%\twilio_api_key_sid.txt"
set /p API_KEY_SECRET=<"%TEMP%\twilio_api_key_secret.txt"
del "%TEMP%\twilio_api_key_sid.txt" 2>nul
del "%TEMP%\twilio_api_key_secret.txt" 2>nul

if "%API_KEY_SID%"=="" (
    echo Error: Could not extract SID from response.
    exit /b 1
)

if "%API_KEY_SECRET%"=="" (
    echo Error: Could not extract secret from response.
    exit /b 1
)

:: Update .env with the new API Key SID and Secret
findstr /v "^TWILIO_API_KEY_SID=" "%ENV_FILE%" > "%ENV_FILE%.tmp"
echo TWILIO_API_KEY_SID=%API_KEY_SID%>> "%ENV_FILE%.tmp"
move /y "%ENV_FILE%.tmp" "%ENV_FILE%" > nul

findstr /v "^TWILIO_API_KEY_SECRET=" "%ENV_FILE%" > "%ENV_FILE%.tmp"
echo TWILIO_API_KEY_SECRET=%API_KEY_SECRET%>> "%ENV_FILE%.tmp"
move /y "%ENV_FILE%.tmp" "%ENV_FILE%" > nul

echo API Key created: %API_KEY_SID%
echo TWILIO_API_KEY_SID and TWILIO_API_KEY_SECRET saved to .env
echo.
echo IMPORTANT: Store the API Key Secret securely - it cannot be retrieved again.
endlocal
