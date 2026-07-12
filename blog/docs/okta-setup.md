# Okta Setup Guide

Configure Okta as your OAuth 2.0 authorization server for Twilio webhooks.

## 1. Create a Service Application

1. Log in to your [Okta Admin Console](https://your-org.okta.com/admin)
2. Go to **Applications > Applications > Create App Integration**
3. Select **API Services** and click **Next**
4. Name it "Twilio Webhooks" and click **Save**

## 2. Get Your Credentials

From the application's **General** tab:

- **Client ID** — shown in the Client Credentials section
- **Client Secret** — click the eye icon to reveal

## 3. Find Your Token URL and JWKS URI

Your Okta org has a default Authorization Server:

- Token URL: `https://YOUR_ORG.okta.com/oauth2/default/v1/token`
- JWKS URI: `https://YOUR_ORG.okta.com/oauth2/default/v1/keys`
- Issuer: `https://YOUR_ORG.okta.com/oauth2/default`

Or use the Org Authorization Server (no custom scopes):

- Token URL: `https://YOUR_ORG.okta.com/oauth2/v1/token`
- JWKS URI: `https://YOUR_ORG.okta.com/oauth2/v1/keys`
- Issuer: `https://YOUR_ORG.okta.com`

## 4. Update .env

```bash
OAUTH_TOKEN_URL=https://YOUR_ORG.okta.com/oauth2/default/v1/token
OAUTH_CLIENT_ID=your_okta_client_id
OAUTH_CLIENT_SECRET=your_okta_client_secret
OAUTH_AUDIENCE=
OAUTH_SCOPE=
OAUTH_JWKS_URI=https://YOUR_ORG.okta.com/oauth2/default/v1/keys
OAUTH_ISSUER=https://YOUR_ORG.okta.com/oauth2/default
```

## Notes

- If you use a custom Authorization Server, you can define custom scopes under **Security > API > Authorization Servers > Your Server > Scopes**
- Default token lifetime is 1 hour. Configure under the access policy rules.
