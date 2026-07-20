# Twilio Function - OAuth Webhook Proxy

A deployable Twilio Function that accepts incoming OAuth-protected webhooks from Twilio and forwards them to a downstream service with:

- The original OAuth `Bearer` token (from the `Authorization` header)
- An `X-API-Key` header for downstream authentication
- The original `X-Twilio-Signature` header (if present)

## Setup

1. Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

| Variable | Description |
|----------|-------------|
| `ACCOUNT_SID` | Your Twilio Account SID |
| `AUTH_TOKEN` | Your Twilio Auth Token |
| `DOWNSTREAM_URL` | The external URL to forward webhook payloads to |
| `DOWNSTREAM_API_KEY` | The API key sent as `X-API-Key` to the downstream service |

2. Install dependencies:

```bash
npm install
```

## Local Development

```bash
npm start
```

This builds the TypeScript and starts the local Twilio Functions server. The webhook endpoint will be available at:

```
http://localhost:3000/webhook
```

## Deploy

```bash
npm run deploy
```

Or using the Twilio CLI directly:

```bash
twilio serverless:deploy
```

After deployment, configure your Twilio webhook URL to point to your deployed function URL (e.g., `https://twilio-function-XXXX.twil.io/webhook`).

## How It Works

1. Twilio sends a webhook to `/webhook` with an OAuth Bearer token in the `Authorization` header
2. The function validates the Bearer token is present
3. The function forwards the entire webhook payload as JSON to `DOWNSTREAM_URL`
4. The forwarded request includes:
   - `Authorization: Bearer <token>` — the original OAuth token from Twilio
   - `X-API-Key: <key>` — your configured downstream API key
   - `X-Twilio-Signature` — preserved if present in the original request
5. The downstream response is returned back to Twilio
