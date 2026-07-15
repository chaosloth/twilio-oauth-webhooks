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

### 2. Configure your environment

```bash
cp .env.example .env
# Edit .env with your Twilio API key and OAuth server details
```

```powershell
Copy-Item .env.example .env
# Edit .env with your Twilio API key and OAuth server details
```

### 3. Start a webhook server

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

### 4. Expose with ngrok (two tunnels)

Twilio needs to reach both your OAuth server and webhook server. Run two tunnels:

```bash
# Terminal 1 — Keycloak
ngrok http 8080

# Terminal 2 — Webhook server
ngrok http 3000
```

Or use an ngrok config to start both at once (`ngrok start --all`). Update `.env` with both ngrok URLs — replace `localhost:8080` in all OAuth URLs, and set `WEBHOOK_URL` to the webhook tunnel.

### 5. Configure Twilio

Run the full setup interactively:

```bash
./scripts/setup.sh
```

Or run individual steps:

**Bash:**

```bash
./scripts/create-setting.sh      # Create webhook setting
./scripts/configure-oauth.sh     # Attach OAuth config
./scripts/test-webhook.sh        # Test against your server
./scripts/enable-default.sh      # Enable for all webhooks
```

**PowerShell:**

```powershell
.\scripts\configure-oauth.ps1     # Attach OAuth config
.\scripts\test-webhook.ps1        # Test against your server
.\scripts\create-rule.ps1         # Create a webhook rule
.\scripts\delete-rule.ps1         # Delete a webhook rule
.\scripts\inspect-webhook.ps1     # Inspect incoming webhook headers
```

### 6. Tear down

```bash
./scripts/teardown.sh
```

## Project Structure

```
├── blog/                    Blog post (markdown)
├── scripts/                 Bash & PowerShell scripts for Twilio API configuration
├── servers/
│   ├── typescript/          Express + jose webhook server
│   ├── python/              FastAPI + python-jose webhook server
│   └── golang/              net/http + golang-jwt webhook server
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
- Event Streams Webhook Sinks do not support OAuth
- Compatible with Restricted API Key (RAK) Signature validation

## Blog Post

Read the full walkthrough: [blog/twilio-oauth-webhooks.md](blog/twilio-oauth-webhooks.md)
