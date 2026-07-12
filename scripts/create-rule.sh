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

# Default to catch-all filter, can be overridden via argument
FILTER="${1:-*}"
PRIORITY="${2:-100}"
TRAFFIC_PERCENTAGE="${3:-100}"

echo "Creating webhook rule..."
echo "  Setting: ${WEBHOOK_SETTING_SID}"
echo "  Filter: ${FILTER}"
echo "  Priority: ${PRIORITY}"
echo "  Traffic: ${TRAFFIC_PERCENTAGE}%"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST https://preview.twilio.com/Webhooks/Rules \
  -H 'Content-Type: application/json' \
  -u "${TWILIO_API_KEY_SID}:${TWILIO_API_KEY_SECRET}" \
  -d "{
    \"webhook_setting_sid\": \"${WEBHOOK_SETTING_SID}\",
    \"filter\": \"${FILTER}\",
    \"priority\": ${PRIORITY},
    \"traffic_percentage\": ${TRAFFIC_PERCENTAGE}
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "201" ]; then
  echo "Error: Expected 201, got ${HTTP_CODE}"
  echo "$BODY"
  exit 1
fi

RULE_SID=$(echo "$BODY" | grep -o '"sid":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$RULE_SID" ]; then
  echo "Error: Could not extract Rule SID from response"
  echo "$BODY"
  exit 1
fi

# Save rule SID to .env
if grep -q "^WEBHOOK_RULE_SID=" "$ENV_FILE"; then
  sed -i '' "s/^WEBHOOK_RULE_SID=.*/WEBHOOK_RULE_SID=${RULE_SID}/" "$ENV_FILE"
else
  echo "WEBHOOK_RULE_SID=${RULE_SID}" >> "$ENV_FILE"
fi

echo "Webhook rule created: ${RULE_SID}"
echo "WEBHOOK_RULE_SID saved to .env"
echo "Changes take up to 5 minutes to take effect."
