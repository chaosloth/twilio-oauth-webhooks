@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "ENV_FILE=%SCRIPT_DIR%..\.env"

echo === Twilio OAuth Webhook Setup ===
echo.

:: Step 1: Create API Key (if not already set)
set "TWILIO_API_KEY_SID="
if exist "%ENV_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
        set "LINE=%%A"
        if not "!LINE:~0,1!"=="#" (
            set "%%A=%%B"
        )
    )
)

if "%TWILIO_API_KEY_SID%"=="" goto :ask_api_key
if "%TWILIO_API_KEY_SID%"=="SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" goto :ask_api_key
echo Step 1: API Key already configured (%TWILIO_API_KEY_SID%)
echo.
goto :step2

:ask_api_key
echo Step 1: Create a Twilio API Key
echo   You can create one in the Console or use this script.
echo   Requires TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN_SECRET in .env.
set /p "REPLY=  Create API Key now? (y/n) "
if /i "%REPLY%"=="y" (
    call "%SCRIPT_DIR%create-api-key.bat"
    :: Re-read .env
    for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
        set "LINE=%%A"
        if not "!LINE:~0,1!"=="#" (
            set "%%A=%%B"
        )
    )
)
echo.

:step2
:: Step 2: Create setting
echo Step 2: Creating webhook setting...
call "%SCRIPT_DIR%create-setting.bat"
if errorlevel 1 exit /b 1
echo.

:: Step 3: Configure OAuth
set /p "REPLY=Step 3: Configure OAuth 2.0? (y/n) "
if /i "%REPLY%"=="y" (
    call "%SCRIPT_DIR%configure-oauth.bat"
)
echo.

:: Step 4: Configure PSK Signature Validation (optional)
echo Step 4: Configure Pre-Shared Key (PSK) Signature Validation
echo   This creates a dedicated signing key for X-Twilio-Signature (instead of the auth token).
echo   Enables key rotation without downtime.
set /p "REPLY=  Configure PSK signature? (y/n) "
if /i "%REPLY%"=="y" (
    call "%SCRIPT_DIR%configure-signature.bat"
)
echo.

:: Step 5: Test
echo Step 5: Test webhook endpoint
echo   This requires your webhook server AND ngrok tunnel to be running.
echo   Start one with:
echo     TypeScript: npm --prefix servers/typescript run dev
echo     Python:     python3 servers/python/server.py
echo     Go:         servers\golang\golang-server.exe
echo   Skip if not ready - you can test later with: scripts\test-webhook.bat
set /p "REPLY=  Test now? (y/n) "
if /i "%REPLY%"=="y" (
    call "%SCRIPT_DIR%test-webhook.bat"
)

:: Step 6: Create webhook rule to apply setting
echo.
echo Step 6: Create a Webhook Rule to apply this setting to your webhooks.
echo   Default: catch-all filter '*' (applies to all webhooks)
echo   You can also run: scripts\create-rule.bat "https://your-domain.com/*"
set /p "REPLY=  Create catch-all rule now? (y/n) "
if /i "%REPLY%"=="y" (
    call "%SCRIPT_DIR%create-rule.bat"
)

echo.
echo === Setup complete ===
echo Changes take up to 5 minutes to take effect.
endlocal
