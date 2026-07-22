#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: .env file not found. Copy .env.example to .env and fill in your values."
  exit 1
fi

source "$ENV_FILE"

if [ -z "${WEBHOOK_SETTING_SID:-}" ]; then
  echo "Error: WEBHOOK_SETTING_SID not set. Run create-setting.sh first."
  exit 1
fi

echo "Creating signature key for webhook setting ${WEBHOOK_SETTING_SID}..."

# Step 1: Create a new signature key
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "https://preview.twilio.com/Webhooks/Settings/${WEBHOOK_SETTING_SID}/SignatureKeys" \
  -H 'Content-Type: application/json' \
  -u "${TWILIO_API_KEY_SID}:${TWILIO_API_KEY_SECRET}" \
  -d '{}')

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "201" ]; then
  echo "Error: Expected 201, got ${HTTP_CODE}"
  echo "$BODY"
  exit 1
fi

KEY_SID=$(echo "$BODY" | grep -o '"sid":"[^"]*"' | head -1 | cut -d'"' -f4)
KEY_SECRET=$(echo "$BODY" | grep -o '"secret":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$KEY_SID" ] || [ -z "$KEY_SECRET" ]; then
  echo "Error: Could not extract key SID or secret from response"
  echo "$BODY"
  exit 1
fi

echo "Signature key created: ${KEY_SID}"

# Step 2: Activate the signature key on the webhook setting
echo "Activating signature validation on webhook setting ${WEBHOOK_SETTING_SID}..."

RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "https://preview.twilio.com/Webhooks/Settings/${WEBHOOK_SETTING_SID}" \
  -H 'Content-Type: application/json' \
  -u "${TWILIO_API_KEY_SID}:${TWILIO_API_KEY_SECRET}" \
  -d "{
    \"signature\": {
      \"type\": \"shared_key\",
      \"shared_key\": {
        \"key_sid\": \"${KEY_SID}\"
      },
      \"enabled\": true
    }
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
  echo "Error: Expected 200, got ${HTTP_CODE}"
  echo "$BODY"
  exit 1
fi

# Save SIGNATURE_KEY_SID to .env
if grep -q "^SIGNATURE_KEY_SID=" "$ENV_FILE"; then
  sed -i '' "s/^SIGNATURE_KEY_SID=.*/SIGNATURE_KEY_SID=${KEY_SID}/" "$ENV_FILE"
else
  echo "SIGNATURE_KEY_SID=${KEY_SID}" >> "$ENV_FILE"
fi

# Save SIGNATURE_KEY_SECRET to .env
if grep -q "^SIGNATURE_KEY_SECRET=" "$ENV_FILE"; then
  sed -i '' "s/^SIGNATURE_KEY_SECRET=.*/SIGNATURE_KEY_SECRET=${KEY_SECRET}/" "$ENV_FILE"
else
  echo "SIGNATURE_KEY_SECRET=${KEY_SECRET}" >> "$ENV_FILE"
fi

echo "Signature validation configured successfully."
echo "SIGNATURE_KEY_SID saved to .env: ${KEY_SID}"
echo "SIGNATURE_KEY_SECRET saved to .env"
echo ""
echo "IMPORTANT: Use the SIGNATURE_KEY_SECRET to validate webhook signatures on your server."
