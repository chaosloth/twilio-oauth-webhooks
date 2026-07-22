#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: .env file not found. Copy .env.example to .env and fill in your values."
  exit 1
fi

source "$ENV_FILE"

# Step 1: Delete webhook rule (must be removed before the setting can be deleted)
if [ -n "${WEBHOOK_RULE_SID:-}" ]; then
  echo "Deleting webhook rule ${WEBHOOK_RULE_SID}..."
  RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "https://preview.twilio.com/Webhooks/Rules/${WEBHOOK_RULE_SID}" \
    -u "${TWILIO_API_KEY_SID}:${TWILIO_API_KEY_SECRET}")
  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  if [ "$HTTP_CODE" != "204" ] && [ "$HTTP_CODE" != "200" ]; then
    echo "Warning: Rule delete returned ${HTTP_CODE} (expected 204)"
  fi
  sed -i '' "s/^WEBHOOK_RULE_SID=.*/WEBHOOK_RULE_SID=/" "$ENV_FILE"
  echo "Rule deleted."
else
  echo "No WEBHOOK_RULE_SID set, skipping rule deletion."
fi

# Step 2: Delete webhook setting (also removes any signature keys associated with it)
if [ -n "${WEBHOOK_SETTING_SID:-}" ]; then
  echo "Deleting webhook setting ${WEBHOOK_SETTING_SID}..."
  RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "https://preview.twilio.com/Webhooks/Settings/${WEBHOOK_SETTING_SID}" \
    -u "${TWILIO_API_KEY_SID}:${TWILIO_API_KEY_SECRET}")
  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  if [ "$HTTP_CODE" != "204" ] && [ "$HTTP_CODE" != "200" ]; then
    echo "Warning: Setting delete returned ${HTTP_CODE} (expected 204)"
  fi
  sed -i '' "s/^WEBHOOK_SETTING_SID=.*/WEBHOOK_SETTING_SID=/" "$ENV_FILE"
  echo "Setting deleted."
else
  echo "No WEBHOOK_SETTING_SID set, skipping setting deletion."
fi

# Step 3: Clear signature key values from .env
if [ -n "${SIGNATURE_KEY_SID:-}" ]; then
  sed -i '' "s/^SIGNATURE_KEY_SID=.*/SIGNATURE_KEY_SID=/" "$ENV_FILE"
  sed -i '' "s/^SIGNATURE_KEY_SECRET=.*/SIGNATURE_KEY_SECRET=/" "$ENV_FILE"
  echo "Signature key values cleared from .env."
fi

echo "Teardown complete. OAuth and PSK signature validation will no longer be applied to webhooks."
