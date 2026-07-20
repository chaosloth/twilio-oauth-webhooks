import os
import json
from typing import Optional

import httpx
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.responses import PlainTextResponse
from jose import JWTError, jwt
from twilio.request_validator import RequestValidator

# Load .env from project root
load_dotenv(os.path.join(os.path.dirname(__file__), "..", "..", ".env"))

PORT = int(os.getenv("WEBHOOK_PORT", "3000"))
JWKS_URI = os.getenv("OAUTH_JWKS_URI")
ISSUER = os.getenv("OAUTH_ISSUER")
TWILIO_AUTH_TOKEN_SECRET = os.getenv("TWILIO_AUTH_TOKEN_SECRET", "")

if not JWKS_URI:
    raise RuntimeError("OAUTH_JWKS_URI is required in .env")

# Cache JWKS keys
_jwks_cache: Optional[dict] = None


async def get_jwks() -> dict:
    global _jwks_cache
    if _jwks_cache is None:
        async with httpx.AsyncClient() as client:
            resp = await client.get(JWKS_URI)
            resp.raise_for_status()
            _jwks_cache = resp.json()
    return _jwks_cache


async def validate_token(authorization: Optional[str] = Header(None)) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        print("--- Token validation failed: Missing or invalid Authorization header ---")
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")

    token = authorization[7:]
    jwks = await get_jwks()

    try:
        # Get the signing key from JWKS
        unverified_header = jwt.get_unverified_header(token)
        kid = unverified_header.get("kid")

        key = None
        for k in jwks.get("keys", []):
            if k.get("kid") == kid:
                key = k
                break

        if key is None:
            # Refresh JWKS cache and retry
            global _jwks_cache
            _jwks_cache = None
            jwks = await get_jwks()
            for k in jwks.get("keys", []):
                if k.get("kid") == kid:
                    key = k
                    break

        if key is None:
            print(f"--- Token validation failed: Signing key not found (kid={kid}) ---")
            raise HTTPException(status_code=401, detail="Signing key not found")

        payload = jwt.decode(
            token,
            key,
            algorithms=["RS256", "RS384", "RS512"],
            issuer=ISSUER if ISSUER else None,
            options={"verify_aud": False},
        )
        return payload

    except JWTError as e:
        # Log details to help debug issuer/signature/expiry mismatches
        try:
            unverified = jwt.get_unverified_claims(token)
            print(f"--- Token validation failed: {e} ---")
            print(f"    Token issuer: {unverified.get('iss')}")
            print(f"    Expected issuer: {ISSUER}")
            print(f"    Token azp: {unverified.get('azp')}")
            print(f"    Token exp: {unverified.get('exp')}")
        except Exception:
            print(f"--- Token validation failed: {e} (could not decode claims) ---")
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")


app = FastAPI(title="Twilio OAuth Webhook Server")


@app.middleware("http")
async def dump_raw_request(request: Request, call_next):
    if request.url.path == "/webhook":
        raw_body = await request.body()
        print("=" * 60)
        print("RAW INCOMING REQUEST")
        print("=" * 60)
        print(f"{request.method} {request.url.path} HTTP/{request.scope.get('http_version', '1.1')}")
        for key, value in request.headers.items():
            print(f"{key}: {value}")
        print()
        print(raw_body.decode("utf-8", errors="replace"))
        print("=" * 60)
    response = await call_next(request)
    return response


@app.api_route("/webhook", methods=["GET", "POST"])
async def webhook(request: Request, claims: dict = Depends(validate_token)):
    body = {}
    content_type = request.headers.get("content-type", "")

    if "application/x-www-form-urlencoded" in content_type:
        form = await request.form()
        body = dict(form)
    elif "application/json" in content_type:
        body = await request.json()

    print("--- Webhook received ---")
    print(f"Token claims: {json.dumps(claims, indent=2)}")
    print(f"Webhook payload: {json.dumps(body, indent=2, default=str)}")

    # Output X-API-Key if present (e.g., injected by Twilio Function proxy)
    api_key = request.headers.get("x-api-key")
    if api_key:
        print(f"--- X-API-Key: {api_key} ---")

    # Validate X-Twilio-Signature
    twilio_signature = request.headers.get("x-twilio-signature", "")
    if TWILIO_AUTH_TOKEN_SECRET and twilio_signature:
        scheme = request.headers.get("x-forwarded-proto", "https")
        host = request.headers.get("x-forwarded-host", request.headers.get("host", ""))
        request_url = f"{scheme}://{host}{request.url.path}"
        validator = RequestValidator(TWILIO_AUTH_TOKEN_SECRET)
        is_valid = validator.validate(request_url, body, twilio_signature)
        print(f"--- Signature validation: {'VALID' if is_valid else 'INVALID'} ---")
    elif not twilio_signature:
        print("--- Signature validation: SKIPPED (no X-Twilio-Signature header) ---")
    else:
        print("--- Signature validation: SKIPPED (no TWILIO_AUTH_TOKEN_SECRET configured) ---")

    # Determine if Voice or Messaging
    is_voice = "CallSid" in body or "CallStatus" in body

    if is_voice:
        twiml = '<?xml version="1.0" encoding="UTF-8"?>\n<Response>\n  <Say>Hello! This webhook is protected by OAuth 2.0.</Say>\n</Response>'
    else:
        twiml = '<?xml version="1.0" encoding="UTF-8"?>\n<Response>\n  <Message>Hello! This webhook is protected by OAuth 2.0.</Message>\n</Response>'

    return PlainTextResponse(content=twiml, media_type="text/xml")


@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    print(f"Webhook server listening on port {PORT}")
    print(f"JWKS URI: {JWKS_URI}")
    print(f"Issuer: {ISSUER or '(not set)'}")
    uvicorn.run(app, host="0.0.0.0", port=PORT)
