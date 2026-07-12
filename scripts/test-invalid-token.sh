#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: .env file not found. Copy .env.example to .env and fill in your values."
  exit 1
fi

source "$ENV_FILE"

PORT="${WEBHOOK_PORT:-3000}"
BASE_URL="http://localhost:${PORT}"

echo "=== Testing invalid token rejection against ${BASE_URL}/webhook ==="
echo ""

# Test 1: No Authorization header at all
echo "Test 1: No Authorization header"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/webhook" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "From=%2B15551234567&Body=test")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "401" ]; then
  echo "  PASS — got 401 (rejected)"
else
  echo "  FAIL — expected 401, got ${HTTP_CODE}"
  echo "  Body: ${BODY}"
fi
echo ""

# Test 2: Malformed Authorization header (not Bearer)
echo "Test 2: Malformed Authorization header (Basic instead of Bearer)"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/webhook" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Basic dXNlcjpwYXNz" \
  -d "From=%2B15551234567&Body=test")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "401" ]; then
  echo "  PASS — got 401 (rejected)"
else
  echo "  FAIL — expected 401, got ${HTTP_CODE}"
  echo "  Body: ${BODY}"
fi
echo ""

# Test 3: Completely bogus Bearer token (not a JWT)
echo "Test 3: Bogus Bearer token (not a JWT)"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/webhook" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Bearer this-is-not-a-jwt" \
  -d "From=%2B15551234567&Body=test")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "401" ]; then
  echo "  PASS — got 401 (rejected)"
else
  echo "  FAIL — expected 401, got ${HTTP_CODE}"
  echo "  Body: ${BODY}"
fi
echo ""

# Test 4: Well-formed JWT signed with a random key (signature won't match JWKS)
# Header: {"alg":"HS256","typ":"JWT"}
# Payload: {"sub":"attacker","iss":"https://evil.example.com","exp":9999999999}
# Signature: signed with secret "wrong-secret" (won't match any JWKS key)
FAKE_JWT="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhdHRhY2tlciIsImlzcyI6Imh0dHBzOi8vZXZpbC5leGFtcGxlLmNvbSIsImV4cCI6OTk5OTk5OTk5OX0.2mGGMOIPTGbBPbbbbqzuYMd_GjGFFj0mxuDqGnMiRYA"

echo "Test 4: Well-formed JWT signed with wrong key"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/webhook" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Bearer ${FAKE_JWT}" \
  -d "From=%2B15551234567&Body=test")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "401" ]; then
  echo "  PASS — got 401 (rejected)"
else
  echo "  FAIL — expected 401, got ${HTTP_CODE}"
  echo "  Body: ${BODY}"
fi
echo ""

# Test 5: Expired JWT (exp in the past) with wrong key
# Payload: {"sub":"attacker","iss":"https://evil.example.com","exp":1000000000}
EXPIRED_JWT="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhdHRhY2tlciIsImlzcyI6Imh0dHBzOi8vZXZpbC5leGFtcGxlLmNvbSIsImV4cCI6MTAwMDAwMDAwMH0.8FjSmVMOTAnxVoX-CbiKCpYVjkqbXqZbPjx0vgI7MpI"

echo "Test 5: Expired JWT"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/webhook" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Bearer ${EXPIRED_JWT}" \
  -d "From=%2B15551234567&Body=test")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "401" ]; then
  echo "  PASS — got 401 (rejected)"
else
  echo "  FAIL — expected 401, got ${HTTP_CODE}"
  echo "  Body: ${BODY}"
fi
echo ""

echo "=== Done ==="
echo "All tests should show PASS. If any show FAIL, your server may not be rejecting invalid tokens correctly."
