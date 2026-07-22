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

:: Step 1: Delete webhook rule (must be removed before the setting can be deleted)
if "%WEBHOOK_RULE_SID%"=="" (
    echo No WEBHOOK_RULE_SID set, skipping rule deletion.
) else (
    echo Deleting webhook rule %WEBHOOK_RULE_SID%...
    powershell -NoProfile -Command ^
      "$cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('%TWILIO_API_KEY_SID%:%TWILIO_API_KEY_SECRET%'));" ^
      "$headers = @{ 'Content-Type' = 'application/json'; 'Authorization' = \"Basic $cred\" };" ^
      "try {" ^
      "  Invoke-RestMethod -Uri 'https://preview.twilio.com/Webhooks/Rules/%WEBHOOK_RULE_SID%' -Method Delete -Headers $headers | Out-Null;" ^
      "  Write-Host 'Rule deleted.'" ^
      "} catch {" ^
      "  $code = $_.Exception.Response.StatusCode.value__;" ^
      "  Write-Host \"Warning: Rule delete returned $code (expected 204)\"" ^
      "}"

    :: Clear WEBHOOK_RULE_SID in .env
    findstr /v "^WEBHOOK_RULE_SID=" "%ENV_FILE%" > "%ENV_FILE%.tmp"
    echo WEBHOOK_RULE_SID=>> "%ENV_FILE%.tmp"
    move /y "%ENV_FILE%.tmp" "%ENV_FILE%" > nul
)

:: Step 2: Delete webhook setting (also removes any signature keys associated with it)
if "%WEBHOOK_SETTING_SID%"=="" (
    echo No WEBHOOK_SETTING_SID set, skipping setting deletion.
) else (
    echo Deleting webhook setting %WEBHOOK_SETTING_SID%...
    powershell -NoProfile -Command ^
      "$cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('%TWILIO_API_KEY_SID%:%TWILIO_API_KEY_SECRET%'));" ^
      "$headers = @{ 'Content-Type' = 'application/json'; 'Authorization' = \"Basic $cred\" };" ^
      "try {" ^
      "  Invoke-RestMethod -Uri 'https://preview.twilio.com/Webhooks/Settings/%WEBHOOK_SETTING_SID%' -Method Delete -Headers $headers | Out-Null;" ^
      "  Write-Host 'Setting deleted.'" ^
      "} catch {" ^
      "  $code = $_.Exception.Response.StatusCode.value__;" ^
      "  Write-Host \"Warning: Setting delete returned $code (expected 204)\"" ^
      "}"

    :: Clear WEBHOOK_SETTING_SID in .env
    findstr /v "^WEBHOOK_SETTING_SID=" "%ENV_FILE%" > "%ENV_FILE%.tmp"
    echo WEBHOOK_SETTING_SID=>> "%ENV_FILE%.tmp"
    move /y "%ENV_FILE%.tmp" "%ENV_FILE%" > nul
)

:: Step 3: Clear signature key values from .env
if not "%SIGNATURE_KEY_SID%"=="" (
    findstr /v "^SIGNATURE_KEY_SID=" "%ENV_FILE%" > "%ENV_FILE%.tmp"
    echo SIGNATURE_KEY_SID=>> "%ENV_FILE%.tmp"
    move /y "%ENV_FILE%.tmp" "%ENV_FILE%" > nul

    findstr /v "^SIGNATURE_KEY_SECRET=" "%ENV_FILE%" > "%ENV_FILE%.tmp"
    echo SIGNATURE_KEY_SECRET=>> "%ENV_FILE%.tmp"
    move /y "%ENV_FILE%.tmp" "%ENV_FILE%" > nul

    echo Signature key values cleared from .env.
)

echo Teardown complete. OAuth and PSK signature validation will no longer be applied to webhooks.
endlocal
