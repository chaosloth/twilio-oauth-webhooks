#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: .env file not found. Copy .env.example to .env and fill in your values."
  exit 1
fi

source "$ENV_FILE"

echo "Creating webhook setting..."

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST https://preview.twilio.com/Webhooks/Settings \
  -H 'Content-Type: application/json' \
  -u "${TWILIO_API_KEY_SID}:${TWILIO_API_KEY_SECRET}" \
  -d '{
    "name": "Default Webhook Settings"
  }')

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "201" ]; then
  echo "Error: Expected 201, got ${HTTP_CODE}"
  echo "$BODY"
  exit 1
fi

SID=$(echo "$BODY" | grep -o '"sid":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$SID" ]; then
  echo "Error: Could not extract SID from response"
  echo "$BODY"
  exit 1
fi

# Update .env with the new SID
if grep -q "^WEBHOOK_SETTING_SID=" "$ENV_FILE"; then
  sed -i '' "s/^WEBHOOK_SETTING_SID=.*/WEBHOOK_SETTING_SID=${SID}/" "$ENV_FILE"
else
  echo "WEBHOOK_SETTING_SID=${SID}" >> "$ENV_FILE"
fi

echo "Webhook setting created: ${SID}"
echo "WEBHOOK_SETTING_SID saved to .env"
