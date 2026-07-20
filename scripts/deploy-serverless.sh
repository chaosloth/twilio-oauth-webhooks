#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/../twilio-serverless"
ENV_FILE="${PROJECT_DIR}/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: twilio-serverless/.env not found."
  echo "Run: cp twilio-serverless/.env.example twilio-serverless/.env"
  echo "Then fill in ACCOUNT_SID, AUTH_TOKEN, DOWNSTREAM_URL, and DOWNSTREAM_API_KEY."
  exit 1
fi

source "$ENV_FILE"

if [ -z "${ACCOUNT_SID:-}" ] || [ -z "${AUTH_TOKEN:-}" ]; then
  echo "Error: ACCOUNT_SID and AUTH_TOKEN must be set in twilio-serverless/.env"
  exit 1
fi

if [ -z "${DOWNSTREAM_URL:-}" ] || [ -z "${DOWNSTREAM_API_KEY:-}" ]; then
  echo "Error: DOWNSTREAM_URL and DOWNSTREAM_API_KEY must be set in twilio-serverless/.env"
  exit 1
fi

echo "Building twilio-serverless..."
cd "$PROJECT_DIR"
npm run build

echo ""
echo "Deploying to Twilio Functions..."
npx twilio-run deploy \
  --functions-folder dist/functions \
  --assets-folder dist/assets \
  --override-existing-project

echo ""
echo "Deployment complete."
echo "Configure your Twilio webhook URL to point to the /webhook path of the deployed function."
