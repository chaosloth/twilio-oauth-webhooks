# Auth0 Setup Guide

Configure Auth0 as your OAuth 2.0 authorization server for Twilio webhooks.

## 1. Create a Machine-to-Machine Application

1. Log in to your [Auth0 Dashboard](https://manage.auth0.com)
2. Go to **Applications > Applications > Create Application**
3. Choose **Machine to Machine Applications**
4. Name it "Twilio Webhooks" and click **Create**
5. Select an API to authorize (or create a new one — see step 2)

## 2. Create an API (if needed)

1. Go to **Applications > APIs > Create API**
2. Set a name (e.g., "Webhook Server") and identifier (e.g., `https://your-domain/webhooks`)
3. The identifier becomes your `audience` value
4. Click **Create**

## 3. Get Your Credentials

From the Application settings page:

- **Domain** — used to construct the token URL and JWKS URI
- **Client ID** — shown on the application page
- **Client Secret** — shown on the application page

## 4. Update .env

```bash
OAUTH_TOKEN_URL=https://YOUR_DOMAIN.auth0.com/oauth/token
OAUTH_CLIENT_ID=your_auth0_client_id
OAUTH_CLIENT_SECRET=your_auth0_client_secret
OAUTH_AUDIENCE=https://your-domain/webhooks
OAUTH_SCOPE=
OAUTH_JWKS_URI=https://YOUR_DOMAIN.auth0.com/.well-known/jwks.json
OAUTH_ISSUER=https://YOUR_DOMAIN.auth0.com/
```

## Notes

- Auth0's token endpoint expects `audience` in the token request for the access token to be a JWT (otherwise it returns an opaque token)
- Access Token Lifespan defaults to 86400 seconds (24 hours). Configure under **APIs > Your API > Settings**
