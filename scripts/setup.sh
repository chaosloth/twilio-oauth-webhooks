#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

echo "=== Twilio OAuth Webhook Setup ==="
echo ""

# Step 1: Create API Key (if not already set)
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
fi

if [ -z "${TWILIO_API_KEY_SID:-}" ] || [ "${TWILIO_API_KEY_SID}" = "SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" ]; then
  echo "Step 1: Create a Twilio API Key"
  echo "  You can create one in the Console or use this script."
  echo "  Requires TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN_SECRET in .env."
  read -p "  Create API Key now? (y/n) " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    bash "${SCRIPT_DIR}/create-api-key.sh"
    source "$ENV_FILE"
  fi
  echo ""
else
  echo "Step 1: API Key already configured (${TWILIO_API_KEY_SID})"
  echo ""
fi

# Step 2: Create setting
echo "Step 2: Creating webhook setting..."
bash "${SCRIPT_DIR}/create-setting.sh"
echo ""

# Step 3: Configure OAuth
read -p "Step 3: Configure OAuth 2.0? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  bash "${SCRIPT_DIR}/configure-oauth.sh"
fi
echo ""

# Step 4: Configure PSK Signature Validation (optional)
echo "Step 4: Configure Pre-Shared Key (PSK) Signature Validation"
echo "  This creates a dedicated signing key for X-Twilio-Signature (instead of the auth token)."
echo "  Enables key rotation without downtime."
read -p "  Configure PSK signature? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  bash "${SCRIPT_DIR}/configure-signature.sh"
fi
echo ""

# Step 5: Test
echo "Step 5: Test webhook endpoint"
echo "  This requires your webhook server AND ngrok tunnel to be running."
echo "  Start one with:"
echo "    TypeScript: npm --prefix servers/typescript run dev"
echo "    Python:     python3 servers/python/server.py"
echo "    Go:         ./servers/golang/golang-server"
echo "  Skip if not ready — you can test later with: ./scripts/test-webhook.sh"
read -p "  Test now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  bash "${SCRIPT_DIR}/test-webhook.sh"
fi

# Step 6: Create webhook rule to apply setting
echo ""
echo "Step 6: Create a Webhook Rule to apply this setting to your webhooks."
echo "  Default: catch-all filter '*' (applies to all webhooks)"
echo "  You can also pass a URL filter, e.g.: ./scripts/create-rule.sh 'https://your-domain.com/*'"
read -p "  Create catch-all rule now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  bash "${SCRIPT_DIR}/create-rule.sh"
fi

echo ""
echo "=== Setup complete ==="
echo "Changes take up to 5 minutes to take effect."
