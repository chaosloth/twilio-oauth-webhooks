#!/usr/bin/env bash
set -euo pipefail

# Minimal webhook receiver that dumps all headers and body.
# Use this to verify what Twilio actually sends when OAuth is enabled.
#
# Usage:
#   ./scripts/inspect-webhook.sh
#
# Then trigger a webhook (call/SMS your Twilio number, or run test-webhook.sh).
# Look for:
#   - Authorization: Bearer <token>   (proves OAuth is working)
#   - X-Twilio-Signature: <sig>       (proves signature is still sent — or not)
#
# Press Ctrl+C to stop.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
fi

PORT="${WEBHOOK_PORT:-3000}"

echo "=== Webhook Header Inspector ==="
echo "Listening on port ${PORT}..."
echo "Trigger a webhook and inspect the output below."
echo "Looking for: Authorization, X-Twilio-Signature"
echo "Press Ctrl+C to stop."
echo ""
echo "---"

# Use netcat/socat if available, but Python is most portable
python3 -c "
import http.server
import json

class InspectHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8')

        # Raw request dump
        print()
        print('=' * 60)
        print('RAW INCOMING REQUEST')
        print('=' * 60)
        print(f'{self.command} {self.path} {self.request_version}')
        for key, value in self.headers.items():
            print(f'{key}: {value}')
        print()
        print(body)
        print('=' * 60)
        print()

        # Parsed summary
        print('VERDICT:')
        print('-' * 40)

        has_auth = False
        has_sig = False

        for key, value in self.headers.items():
            if key.lower() == 'authorization':
                has_auth = True
            elif key.lower() == 'x-twilio-signature':
                has_sig = True

        if has_auth:
            print('  [x] Authorization header PRESENT (OAuth is working)')
        else:
            print('  [ ] Authorization header MISSING')

        if has_sig:
            print('  [x] X-Twilio-Signature header PRESENT (signature still sent with OAuth)')
        else:
            print('  [ ] X-Twilio-Signature header MISSING (not sent when OAuth is enabled)')

        print()
        print('=' * 60)
        print()

        # Return valid TwiML so Twilio doesn't error
        response = '''<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<Response>
  <Say>Inspecting headers.</Say>
</Response>'''
        self.send_response(200)
        self.send_header('Content-Type', 'text/xml')
        self.end_headers()
        self.wfile.write(response.encode())

    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{\"status\":\"ok\"}')

    def log_message(self, format, *args):
        pass  # suppress default access log

server = http.server.HTTPServer(('0.0.0.0', ${PORT}), InspectHandler)
print(f'Server ready on http://0.0.0.0:${PORT}/webhook')
print()
server.serve_forever()
"
