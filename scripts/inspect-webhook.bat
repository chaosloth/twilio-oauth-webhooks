@echo off
setlocal enabledelayedexpansion

:: Minimal webhook receiver that dumps all headers and body.
:: Use this to verify what Twilio actually sends when OAuth is enabled.
::
:: Usage:
::   scripts\inspect-webhook.bat
::
:: Then trigger a webhook (call/SMS your Twilio number, or run test-webhook.bat).
:: Look for:
::   - Authorization: Bearer <token>   (proves OAuth is working)
::   - X-Twilio-Signature: <sig>       (proves signature is still sent or not)
::
:: Requires: Python 3 (installed by default on many Windows setups, or via Microsoft Store)
:: Press Ctrl+C to stop.

set "SCRIPT_DIR=%~dp0"
set "ENV_FILE=%SCRIPT_DIR%..\.env"

if exist "%ENV_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
        set "LINE=%%A"
        if not "!LINE:~0,1!"=="#" (
            set "%%A=%%B"
        )
    )
)

if "%WEBHOOK_PORT%"=="" set "WEBHOOK_PORT=3000"

echo === Webhook Header Inspector ===
echo Listening on port %WEBHOOK_PORT%...
echo Trigger a webhook and inspect the output below.
echo Looking for: Authorization, X-Twilio-Signature
echo Press Ctrl+C to stop.
echo.
echo ---

python -c "import http.server; PORT=%WEBHOOK_PORT%; exec(open('%SCRIPT_DIR%inspect-webhook-handler.py').read())"
if errorlevel 1 (
    echo Falling back to inline Python server...
    powershell -NoProfile -Command ^
      "$listener = New-Object System.Net.HttpListener;" ^
      "$listener.Prefixes.Add('http://+:%WEBHOOK_PORT%/');" ^
      "$listener.Start();" ^
      "Write-Host 'Server ready on http://0.0.0.0:%WEBHOOK_PORT%/webhook';" ^
      "Write-Host '';" ^
      "while ($true) {" ^
      "  $ctx = $listener.GetContext();" ^
      "  $req = $ctx.Request; $res = $ctx.Response;" ^
      "  if ($req.HttpMethod -eq 'POST') {" ^
      "    $reader = New-Object System.IO.StreamReader($req.InputStream);" ^
      "    $body = $reader.ReadToEnd(); $reader.Close();" ^
      "    Write-Host ''; Write-Host ('=' * 60); Write-Host 'RAW INCOMING REQUEST'; Write-Host ('=' * 60);" ^
      "    Write-Host \"$($req.HttpMethod) $($req.RawUrl) HTTP/$($req.ProtocolVersion)\";" ^
      "    foreach ($k in $req.Headers.AllKeys) { Write-Host \"${k}: $($req.Headers[$k])\" };" ^
      "    Write-Host ''; Write-Host $body; Write-Host ('=' * 60); Write-Host '';" ^
      "    Write-Host 'VERDICT:'; Write-Host ('-' * 40);" ^
      "    if ($req.Headers['Authorization']) { Write-Host '  [x] Authorization header PRESENT (OAuth is working)' } else { Write-Host '  [ ] Authorization header MISSING' };" ^
      "    if ($req.Headers['X-Twilio-Signature']) { Write-Host '  [x] X-Twilio-Signature header PRESENT' } else { Write-Host '  [ ] X-Twilio-Signature header MISSING' };" ^
      "    Write-Host ''; Write-Host ('=' * 60); Write-Host '';" ^
      "    $twiml = [Text.Encoding]::UTF8.GetBytes('<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>Inspecting headers.</Say></Response>');" ^
      "    $res.ContentType = 'text/xml'; $res.ContentLength64 = $twiml.Length; $res.OutputStream.Write($twiml, 0, $twiml.Length)" ^
      "  } else {" ^
      "    $json = [Text.Encoding]::UTF8.GetBytes('{\"status\":\"ok\"}');" ^
      "    $res.ContentType = 'application/json'; $res.ContentLength64 = $json.Length; $res.OutputStream.Write($json, 0, $json.Length)" ^
      "  };" ^
      "  $res.Close()" ^
      "}"
)
endlocal
