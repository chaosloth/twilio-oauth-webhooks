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

if [ -z "${WEBHOOK_URL:-}" ]; then
  echo "Error: WEBHOOK_URL not set in .env."
  exit 1
fi

METHOD="${1:-POST}"

echo "Testing webhook setting ${WEBHOOK_SETTING_SID} against ${WEBHOOK_URL} (${METHOD})..."

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "https://preview.twilio.com/Webhooks/Settings/${WEBHOOK_SETTING_SID}/Test" \
  -H 'Content-Type: application/json' \
  -u "${TWILIO_API_KEY_SID}:${TWILIO_API_KEY_SECRET}" \
  -d "{
    \"method\": \"${METHOD}\",
    \"url\": \"${WEBHOOK_URL}\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
  echo "Error: Expected 200, got ${HTTP_CODE}"
  echo "$BODY"
  echo "Check the Twilio Console Debugger for error details."
  exit 1
fi

echo "Test successful! Your webhook endpoint accepted the OAuth-authenticated request."
