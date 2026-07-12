#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Twilio OAuth Webhook Setup ==="
echo ""

# Step 1: Create setting
echo "Step 1: Creating webhook setting..."
bash "${SCRIPT_DIR}/create-setting.sh"
echo ""

# Step 2: Configure OAuth
read -p "Step 2: Configure OAuth 2.0? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  bash "${SCRIPT_DIR}/configure-oauth.sh"
fi
echo ""

# Step 3: Test
echo "Step 3: Test webhook endpoint"
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

# Step 4: Create webhook rule to apply setting
echo ""
echo "Step 4: Create a Webhook Rule to apply this setting to your webhooks."
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
