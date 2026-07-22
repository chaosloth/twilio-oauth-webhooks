# Building the Webhook Server

Now that Twilio is sending OAuth tokens, your webhook server needs to validate them. Here's a production-ready implementation in TypeScript using Express and the `jose` library.

## Why `jose`?

The `jose` library (JavaScript Object Signing and Encryption) is the modern standard for JWT validation in Node.js. It:
- Automatically fetches and caches public keys from your OAuth server's JWKS endpoint
- Validates token signatures using the correct algorithm
- Checks expiration, issuer, and audience claims
- Handles key rotation seamlessly

Install dependencies:

```bash
npm install express jose dotenv
npm install --save-dev @types/express @types/node typescript
```

## The Middleware Pattern

Here's the complete server from `servers/typescript/src/server.ts`:

```typescript
import "dotenv/config";
import express, { Request, Response, NextFunction } from "express";
import { createRemoteJWKSet, jwtVerify, JWTPayload } from "jose";

const PORT = parseInt(process.env.WEBHOOK_PORT || "3000", 10);
const JWKS_URI = process.env.OAUTH_JWKS_URI;
const ISSUER = process.env.OAUTH_ISSUER;

if (!JWKS_URI) {
  console.error("OAUTH_JWKS_URI is required in .env");
  process.exit(1);
}

const JWKS = createRemoteJWKSet(new URL(JWKS_URI));

interface AuthenticatedRequest extends Request {
  token?: JWTPayload;
}

async function validateToken(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    res.status(401).json({ error: "Missing or invalid Authorization header" });
    return;
  }

  const token = authHeader.slice(7);

  try {
    const { payload } = await jwtVerify(token, JWKS, {
      issuer: ISSUER || undefined,
    });
    req.token = payload;
    next();
  } catch (err) {
    console.error("Token validation failed:", err);
    res.status(401).json({ error: "Invalid token" });
  }
}

const app = express();
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

app.all("/webhook", validateToken, (req: AuthenticatedRequest, res: Response) => {
  console.log("--- Webhook received ---");
  console.log("Token claims:", JSON.stringify(req.token, null, 2));
  console.log("Webhook payload:", JSON.stringify(req.body, null, 2));

  // Determine if this is a Voice or Messaging webhook
  const isVoice = req.body.CallSid || req.body.CallStatus;

  if (isVoice) {
    res.type("text/xml").send(`<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say>Hello! This webhook is protected by OAuth 2.0.</Say>
</Response>`);
  } else {
    res.type("text/xml").send(`<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Message>Hello! This webhook is protected by OAuth 2.0.</Message>
</Response>`);
  }
});

app.get("/health", (_req: Request, res: Response) => {
  res.json({ status: "ok" });
});

app.listen(PORT, () => {
  console.log(`Webhook server listening on port ${PORT}`);
  console.log(`JWKS URI: ${JWKS_URI}`);
  console.log(`Issuer: ${ISSUER || "(not set)"}`);
});
```

## Key Implementation Details

**1. JWKS Initialization**  
`createRemoteJWKSet(new URL(JWKS_URI))` creates a remote key set that automatically:
- Fetches public keys from your OAuth server
- Caches them in memory
- Refreshes them when needed (e.g., key rotation)

**2. Token Extraction**  
The middleware extracts the Bearer token from the `Authorization` header. If missing or malformed, it returns 401.

**3. Token Verification**  
`jwtVerify()` performs cryptographic validation:
- Verifies the signature using the correct public key from JWKS
- Checks that `exp` (expiration) hasn't passed
- Validates the `iss` (issuer) claim matches your expected issuer
- Optionally validates `aud` (audience) if configured

**4. Attaching Claims**  
If validation succeeds, the JWT payload (claims) is attached to `req.token` for downstream handlers to inspect (e.g., `sub`, `client_id`, custom claims).

**5. Returning TwiML**  
Twilio expects an XML response (TwiML) for Voice and Messaging webhooks. The handler detects the webhook type and returns appropriate TwiML.

## Python Implementation

A functionally equivalent FastAPI implementation is provided in `servers/python/server.py` using the `python-jose` library. The pattern is identical:
- Extract Bearer token from `Authorization` header
- Fetch JWKS from your OAuth server
- Verify signature, expiration, and issuer
- Return TwiML on success, 401 on failure

See the Python server for details.

## Go Implementation

The Go implementation in `servers/golang/main.go` uses [`golang-jwt`](https://github.com/golang-jwt/jwt) for JWT validation with automatic JWKS key fetching.

Key libraries:
- `github.com/MicahParks/keyfunc/v3` — fetches and caches JWKS keys automatically
- `github.com/golang-jwt/jwt/v5` — parses and verifies JWTs

The pattern is the same as TypeScript and Python: middleware extracts the Bearer token, validates the JWT signature against JWKS, checks issuer/expiry, and passes claims to the webhook handler.

See the Go server for the complete implementation.
