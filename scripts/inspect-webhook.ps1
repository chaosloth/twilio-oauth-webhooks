$ErrorActionPreference = "Stop"

# Minimal webhook receiver that dumps all headers and body.
# Use this to verify what Twilio actually sends when OAuth is enabled.
#
# Usage:
#   .\scripts\inspect-webhook.ps1
#
# Then trigger a webhook (call/SMS your Twilio number, or run test-webhook.ps1).
# Look for:
#   - Authorization: Bearer <token>   (proves OAuth is working)
#   - X-Twilio-Signature: <sig>       (proves signature is still sent — or not)
#
# Press Ctrl+C to stop.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path (Split-Path -Parent $ScriptDir) ".env"

if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim())
        }
    }
}

$Port = [Environment]::GetEnvironmentVariable("WEBHOOK_PORT")
if ([string]::IsNullOrEmpty($Port)) { $Port = "3000" }

Write-Host "=== Webhook Header Inspector ==="
Write-Host "Listening on port ${Port}..."
Write-Host "Trigger a webhook and inspect the output below."
Write-Host "Looking for: Authorization, X-Twilio-Signature"
Write-Host "Press Ctrl+C to stop."
Write-Host ""
Write-Host "---"

$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add("http://+:${Port}/")
$Listener.Start()

Write-Host "Server ready on http://0.0.0.0:${Port}/webhook"
Write-Host ""

try {
    while ($true) {
        $Context = $Listener.GetContext()
        $Request = $Context.Request
        $Response = $Context.Response

        if ($Request.HttpMethod -eq "POST") {
            $Reader = New-Object System.IO.StreamReader($Request.InputStream)
            $Body = $Reader.ReadToEnd()
            $Reader.Close()

            Write-Host ""
            Write-Host ("=" * 60)
            Write-Host "RAW INCOMING REQUEST"
            Write-Host ("=" * 60)
            Write-Host "$($Request.HttpMethod) $($Request.RawUrl) HTTP/$($Request.ProtocolVersion)"
            foreach ($Key in $Request.Headers.AllKeys) {
                Write-Host "${Key}: $($Request.Headers[$Key])"
            }
            Write-Host ""
            Write-Host $Body
            Write-Host ("=" * 60)
            Write-Host ""

            Write-Host "VERDICT:"
            Write-Host ("-" * 40)

            $HasAuth = $null -ne $Request.Headers["Authorization"]
            $HasSig = $null -ne $Request.Headers["X-Twilio-Signature"]

            if ($HasAuth) {
                Write-Host "  [x] Authorization header PRESENT (OAuth is working)"
            }
            else {
                Write-Host "  [ ] Authorization header MISSING"
            }

            if ($HasSig) {
                Write-Host "  [x] X-Twilio-Signature header PRESENT (signature still sent with OAuth)"
            }
            else {
                Write-Host "  [ ] X-Twilio-Signature header MISSING (not sent when OAuth is enabled)"
            }

            Write-Host ""
            Write-Host ("=" * 60)
            Write-Host ""

            $TwiML = '<?xml version="1.0" encoding="UTF-8"?><Response><Say>Inspecting headers.</Say></Response>'
            $Buffer = [Text.Encoding]::UTF8.GetBytes($TwiML)
            $Response.ContentType = "text/xml"
            $Response.ContentLength64 = $Buffer.Length
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        else {
            $Json = '{"status":"ok"}'
            $Buffer = [Text.Encoding]::UTF8.GetBytes($Json)
            $Response.ContentType = "application/json"
            $Response.ContentLength64 = $Buffer.Length
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }

        $Response.Close()
    }
}
finally {
    $Listener.Stop()
}
