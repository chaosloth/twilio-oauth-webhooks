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

echo "Configuring OAuth 2.0 for webhook setting ${WEBHOOK_SETTING_SID}..."

# Build optional fields
OPTIONAL_FIELDS=""
if [ -n "${OAUTH_SCOPE:-}" ]; then
  OPTIONAL_FIELDS="${OPTIONAL_FIELDS}, \"scope\": \"${OAUTH_SCOPE}\""
fi
if [ -n "${OAUTH_AUDIENCE:-}" ]; then
  OPTIONAL_FIELDS="${OPTIONAL_FIELDS}, \"audience\": \"${OAUTH_AUDIENCE}\""
fi

RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "https://preview.twilio.com/Webhooks/Settings/${WEBHOOK_SETTING_SID}" \
  -H 'Content-Type: application/json' \
  -u "${TWILIO_API_KEY_SID}:${TWILIO_API_KEY_SECRET}" \
  -d "{
    \"auth\": {
      \"enabled\": true,
      \"type\": \"oauth2\",
      \"oauth2\": {
        \"token_url\": \"${OAUTH_TOKEN_URL}\",
        \"client_id\": \"${OAUTH_CLIENT_ID}\",
        \"client_secret\": \"${OAUTH_CLIENT_SECRET}\"${OPTIONAL_FIELDS}
      }
    }
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
  echo "Error: Expected 200, got ${HTTP_CODE}"
  echo "$BODY"
  exit 1
fi

echo "OAuth 2.0 configured successfully."
