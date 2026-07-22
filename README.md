# Twilio OAuth 2.0 Webhooks

Companion code and blog post demonstrating how to configure OAuth 2.0 authentication for Twilio webhooks (Private Beta).

When enabled, Twilio uses the OAuth 2.0 Client Credentials flow to obtain an access token from your Authorization Server, then includes it as a Bearer token in the `Authorization` header of every webhook request. Your server validates the token to confirm the request is authorized.

## Quick Start

### 1. Set up your Authorization Server

**For local testing** (Keycloak via Docker):

```bash
cd infra
docker compose up -d
./keycloak-setup.sh
```

**For production**, see the provider guides:
- [Auth0](docs/auth0-setup.md)
- [Okta](docs/okta-setup.md)
- [Microsoft Entra ID](docs/entra-setup.md)

### 2. Create an API Key

Create a Standard API Key via the [Twilio Console](https://console.twilio.com/us1/account/keys-credentials/api-keys), or use the included script:

```bash
./scripts/create-api-key.sh
```

```powershell
.\scripts\create-api-key.ps1
```

```bat
scripts\create-api-key.bat
```

This calls the Twilio IAM API to create a Standard API Key and saves `TWILIO_API_KEY_SID` and `TWILIO_API_KEY_SECRET` to your `.env` file. Requires `TWILIO_ACCOUNT_SID` and `TWILIO_AUTH_TOKEN_SECRET` to be set.

### 3. Configure your environment

```bash
cp .env.example .env
# Edit .env with your Twilio API key and OAuth server details
```

```powershell
Copy-Item .env.example .env
# Edit .env with your Twilio API key and OAuth server details
```

```bat
copy .env.example .env
REM Edit .env with your Twilio API key and OAuth server details
```

### 4. Start a webhook server

**TypeScript:**

```bash
cd servers/typescript
npm install
npm run dev
```

**Python:**

```bash
cd servers/python
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python3 server.py
```

**Go:**

```bash
cd servers/golang
go build .
./golang-server
```

### Optional: Deploy the Twilio Function proxy

If your downstream service requires an `X-API-Key` header (or other custom headers) alongside the OAuth Bearer token, deploy the Twilio Function as a proxy:

```bash
cd twilio-serverless
cp .env.example .env
# Set DOWNSTREAM_URL and DOWNSTREAM_API_KEY
npm install
npm run deploy
```

The function forwards incoming webhooks to your downstream URL, preserving the Bearer token and adding an `X-API-Key` header. Point your Twilio webhook URL at the deployed function instead of your downstream server directly.

You can also override the downstream URL per-request using the `endpoint` query parameter:

```
https://twilio-serverless-1234.twil.io/webhook?endpoint=https://api.example.com/handler
```

If `endpoint` is not provided, the function falls back to `DOWNSTREAM_URL` from the environment.

### 5. Expose with ngrok (two tunnels)

Twilio needs to reach both your OAuth server and webhook server. Run two tunnels:

```bash
# Terminal 1 — Keycloak
ngrok http 8080

# Terminal 2 — Webhook server
ngrok http 3000
```

Or use an ngrok config to start both at once (`ngrok start --all`). Update `.env` with both ngrok URLs — replace `localhost:8080` in all OAuth URLs, and set `WEBHOOK_URL` to the webhook tunnel.

### 6. Configure Twilio

Run the full setup interactively (walks you through all steps with prompts):

```bash
./scripts/setup.sh
```

```powershell
.\scripts\setup.ps1
```

```bat
scripts\setup.bat
```

Or run individual steps:

**Bash:**

```bash
./scripts/create-api-key.sh          # Create API key (alternative to Console)
./scripts/create-setting.sh          # Create webhook setting
./scripts/configure-oauth.sh         # Attach OAuth config
./scripts/configure-signature.sh     # Configure PSK signature validation (optional)
./scripts/test-webhook.sh            # Test against your server
./scripts/create-rule.sh             # Create a webhook rule
```

**PowerShell:**

```powershell
.\scripts\create-api-key.ps1          # Create API key (alternative to Console)
.\scripts\create-setting.ps1          # Create webhook setting
.\scripts\configure-oauth.ps1         # Attach OAuth config
.\scripts\configure-signature.ps1     # Configure PSK signature validation (optional)
.\scripts\test-webhook.ps1            # Test against your server
.\scripts\create-rule.ps1             # Create a webhook rule
.\scripts\delete-rule.ps1             # Delete a webhook rule
.\scripts\inspect-webhook.ps1         # Inspect incoming webhook headers
```

**CMD (Windows batch with curl):**

```bat
scripts\create-api-key.bat            REM Create API key (alternative to Console)
scripts\create-setting.bat            REM Create webhook setting
scripts\configure-oauth.bat           REM Attach OAuth config
scripts\configure-signature.bat       REM Configure PSK signature validation (optional)
scripts\test-webhook.bat              REM Test against your server
scripts\create-rule.bat               REM Create a webhook rule
scripts\delete-rule.bat               REM Delete a webhook rule
scripts\inspect-webhook.bat           REM Inspect incoming webhook headers
```

### Optional: Configure PSK Signature Validation

Pre-Shared Key (PSK) signature validation lets Twilio sign webhooks with a dedicated key instead of the account auth token. This enables key rotation without downtime.

```bash
./scripts/configure-signature.sh
```

```powershell
.\scripts\configure-signature.ps1
```

```bat
scripts\configure-signature.bat
```

This creates a signature key, activates it on your webhook setting, and saves `SIGNATURE_KEY_SID` and `SIGNATURE_KEY_SECRET` to `.env`. Use the secret to validate `X-Twilio-Signature` on incoming webhooks. The `X-Twilio-Signature-Key-Sid` header identifies which key was used.

### 7. Tear down

Removes the webhook rule, webhook setting, and clears signature key values from `.env`:

```bash
./scripts/teardown.sh
```

```powershell
.\scripts\teardown.ps1
```

```bat
scripts\teardown.bat
```

## Project Structure

```
├── blog/                    Blog post (markdown)
├── scripts/                 Bash, PowerShell & batch scripts for Twilio API configuration
├── servers/
│   ├── typescript/          Express + jose webhook server
│   ├── python/              FastAPI + python-jose webhook server
│   └── golang/              net/http + golang-jwt webhook server
├── twilio-serverless/         Twilio Functions proxy for header manipulation (adds X-API-Key)
├── infra/                   Keycloak docker-compose + setup
└── docs/                    Auth0, Okta, Entra setup guides
```

## How It Works

1. You configure OAuth 2.0 credentials in Twilio's Webhook Settings API
2. When Twilio sends a webhook, it first requests an access token from your Authorization Server
3. Twilio includes the token as `Authorization: Bearer <token>` in the webhook request
4. Your server validates the JWT against the Authorization Server's JWKS endpoint

## Important Notes

- Changes take ~5 seconds to propagate after enabling/disabling OAuth
- If token fetch fails (server down, invalid credentials), Twilio retries 2x (250ms apart), then drops the webhook
- After failure, Twilio waits 300 seconds before retrying token fetch
- OAuth does NOT replace webhook signature validation — continue checking `X-Twilio-Signature`
- PSK signature validation and OAuth are independent and can be used together
- Event Streams Webhook Sinks do not support OAuth
- Compatible with Restricted API Key (RAK) Signature validation

## Blog Post

Read the full walkthrough: [blog/twilio-oauth-webhooks.md](blog/twilio-oauth-webhooks.md)
