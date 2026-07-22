#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: .env file not found. Copy .env.example to .env and fill in your values."
  exit 1
fi

source "$ENV_FILE"

if [ -z "${TWILIO_ACCOUNT_SID:-}" ]; then
  echo "Error: TWILIO_ACCOUNT_SID not set in .env."
  exit 1
fi

if [ -z "${TWILIO_AUTH_TOKEN_SECRET:-}" ]; then
  echo "Error: TWILIO_AUTH_TOKEN_SECRET not set in .env."
  exit 1
fi

echo "Creating Twilio Standard API Key..."

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST https://iam.twilio.com/v1/Keys \
  -u "${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN_SECRET}" \
  --data-urlencode "AccountSid=${TWILIO_ACCOUNT_SID}" \
  --data-urlencode "FriendlyName=Twilio Webhooks API Key")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "201" ]; then
  echo "Error: Expected 201, got ${HTTP_CODE}"
  echo "$BODY"
  exit 1
fi

API_KEY_SID=$(echo "$BODY" | grep -o '"sid":"[^"]*"' | head -1 | cut -d'"' -f4)
API_KEY_SECRET=$(echo "$BODY" | grep -o '"secret":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$API_KEY_SID" ]; then
  echo "Error: Could not extract SID from response"
  echo "$BODY"
  exit 1
fi

if [ -z "$API_KEY_SECRET" ]; then
  echo "Error: Could not extract secret from response"
  echo "$BODY"
  exit 1
fi

# Update .env with the new API Key SID
if grep -q "^TWILIO_API_KEY_SID=" "$ENV_FILE"; then
  sed -i '' "s/^TWILIO_API_KEY_SID=.*/TWILIO_API_KEY_SID=${API_KEY_SID}/" "$ENV_FILE"
else
  echo "TWILIO_API_KEY_SID=${API_KEY_SID}" >> "$ENV_FILE"
fi

# Update .env with the new API Key Secret
if grep -q "^TWILIO_API_KEY_SECRET=" "$ENV_FILE"; then
  sed -i '' "s/^TWILIO_API_KEY_SECRET=.*/TWILIO_API_KEY_SECRET=${API_KEY_SECRET}/" "$ENV_FILE"
else
  echo "TWILIO_API_KEY_SECRET=${API_KEY_SECRET}" >> "$ENV_FILE"
fi

echo "API Key created: ${API_KEY_SID}"
echo "TWILIO_API_KEY_SID and TWILIO_API_KEY_SECRET saved to .env"
echo ""
echo "IMPORTANT: Store the API Key Secret securely - it cannot be retrieved again."
