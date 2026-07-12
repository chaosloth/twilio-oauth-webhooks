#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: .env file not found. Copy .env.example to .env and fill in your values."
  exit 1
fi

source "$ENV_FILE"

if [ -z "${WEBHOOK_RULE_SID:-}" ]; then
  echo "Error: WEBHOOK_RULE_SID not set. Nothing to delete."
  exit 1
fi

echo "Deleting webhook rule ${WEBHOOK_RULE_SID}..."

RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "https://preview.twilio.com/Webhooks/Rules/${WEBHOOK_RULE_SID}" \
  -u "${TWILIO_API_KEY_SID}:${TWILIO_API_KEY_SECRET}")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)

if [ "$HTTP_CODE" != "204" ] && [ "$HTTP_CODE" != "200" ]; then
  BODY=$(echo "$RESPONSE" | sed '$d')
  echo "Error: Expected 204, got ${HTTP_CODE}"
  echo "$BODY"
  exit 1
fi

# Clear the rule SID from .env
sed -i '' "s/^WEBHOOK_RULE_SID=.*/WEBHOOK_RULE_SID=/" "$ENV_FILE"

echo "Webhook rule deleted. WEBHOOK_RULE_SID cleared from .env."
echo "Changes take up to 5 minutes to take effect."
