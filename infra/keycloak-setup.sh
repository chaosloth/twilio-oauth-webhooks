#!/usr/bin/env bash
set -euo pipefail

KEYCLOAK_URL="${1:-http://localhost:8080}"
REALM="master"
CLIENT_ID="twilio-webhook-client"
ADMIN_USER="admin"
ADMIN_PASS="admin"

echo "Waiting for Keycloak to be ready..."
until curl -sf "${KEYCLOAK_URL}/realms/master" > /dev/null 2>&1; do
  sleep 2
done
echo "Keycloak is ready."

# Get admin token
echo "Authenticating as admin..."
ADMIN_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$ADMIN_TOKEN" ]; then
  echo "Error: Failed to get admin token"
  exit 1
fi

# Create client
echo "Creating client '${CLIENT_ID}'..."
CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/clients" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"clientId\": \"${CLIENT_ID}\",
    \"enabled\": true,
    \"clientAuthenticatorType\": \"client-secret\",
    \"serviceAccountsEnabled\": true,
    \"directAccessGrantsEnabled\": false,
    \"standardFlowEnabled\": false,
    \"publicClient\": false
  }")

HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -1)

if [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "409" ]; then
  echo "Error creating client: HTTP ${HTTP_CODE}"
  echo "$CREATE_RESPONSE" | sed '$d'
  exit 1
fi

if [ "$HTTP_CODE" = "409" ]; then
  echo "Client already exists, fetching existing..."
fi

# Get the client's internal ID
INTERNAL_ID=$(curl -s "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=${CLIENT_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

# Get client secret
CLIENT_SECRET=$(curl -s "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${INTERNAL_ID}/client-secret" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | grep -o '"value":"[^"]*"' | cut -d'"' -f4)

echo ""
echo "=== Keycloak Client Created ==="
echo ""
echo "Add these values to your .env file:"
echo ""
echo "OAUTH_TOKEN_URL=${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token"
echo "OAUTH_CLIENT_ID=${CLIENT_ID}"
echo "OAUTH_CLIENT_SECRET=${CLIENT_SECRET}"
echo "OAUTH_JWKS_URI=${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/certs"
echo "OAUTH_ISSUER=${KEYCLOAK_URL}/realms/${REALM}"
echo ""
echo "If using ngrok, replace 'http://localhost:8080' with your ngrok URL."
