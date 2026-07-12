import path from "path";
import dotenv from "dotenv";
dotenv.config({ path: path.resolve(process.cwd(), "..", "..", ".env") });

import express, { Request, Response, NextFunction } from "express";
import { createRemoteJWKSet, jwtVerify, JWTPayload } from "jose";
import { validateRequest } from "twilio";

const PORT = parseInt(process.env.WEBHOOK_PORT || "3000", 10);
const JWKS_URI = process.env.OAUTH_JWKS_URI;
const ISSUER = process.env.OAUTH_ISSUER;
const TWILIO_AUTH_TOKEN_SECRET = process.env.TWILIO_AUTH_TOKEN_SECRET || "";

if (!JWKS_URI) {
  console.error("OAUTH_JWKS_URI is required in .env");
  process.exit(1);
}

const JWKS = createRemoteJWKSet(new URL(JWKS_URI));

interface AuthenticatedRequest extends Request {
  token?: JWTPayload;
}

async function validateToken(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
  console.log("============================================================");
  console.log("RAW INCOMING REQUEST");
  console.log("============================================================");
  console.log(`${req.method} ${req.originalUrl} HTTP/${req.httpVersion}`);
  for (const [key, value] of Object.entries(req.headers)) {
    console.log(`${key}: ${value}`);
  }
  console.log();
  console.log(req.rawBody || "");
  console.log("============================================================");

  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    console.log("--- Token validation failed: Missing or invalid Authorization header ---");
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

declare global {
  namespace Express {
    interface Request {
      rawBody?: string;
    }
  }
}

app.use(
  express.urlencoded({
    extended: true,
    verify: (req: any, _res, buf) => {
      req.rawBody = buf.toString();
    },
  }),
);
app.use(
  express.json({
    verify: (req: any, _res, buf) => {
      req.rawBody = buf.toString();
    },
  }),
);

app.all("/webhook", validateToken, (req: AuthenticatedRequest, res: Response) => {
  console.log("--- Webhook received ---");
  console.log("Token claims:", JSON.stringify(req.token, null, 2));
  console.log("Webhook payload:", JSON.stringify(req.body, null, 2));

  // Validate X-Twilio-Signature
  const twilioSignature = req.headers["x-twilio-signature"] as string | undefined;
  if (TWILIO_AUTH_TOKEN_SECRET && twilioSignature) {
    const protocol = req.headers["x-forwarded-proto"] || req.protocol;
    const host = req.headers["x-forwarded-host"] || req.headers.host;
    const requestUrl = `${protocol}://${host}${req.originalUrl}`;
    const isValid = validateRequest(TWILIO_AUTH_TOKEN_SECRET, twilioSignature, requestUrl, req.body);
    console.log(`--- Signature validation: ${isValid ? "VALID" : "INVALID"} ---`);
  } else if (!twilioSignature) {
    console.log("--- Signature validation: SKIPPED (no X-Twilio-Signature header) ---");
  } else {
    console.log("--- Signature validation: SKIPPED (no TWILIO_AUTH_TOKEN_SECRET configured) ---");
  }

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
