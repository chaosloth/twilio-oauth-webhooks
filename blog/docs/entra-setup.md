# Microsoft Entra ID Setup Guide

Configure Microsoft Entra ID (formerly Azure Active Directory) as your OAuth 2.0 authorization server for Twilio webhooks.

## 1. Register an Application

1. Log in to the [Azure Portal](https://portal.azure.com)
2. Go to **Microsoft Entra ID > App registrations > New registration**
3. Name it "Twilio Webhooks"
4. Set **Supported account types** to "Accounts in this organizational directory only"
5. Click **Register**

## 2. Create a Client Secret

1. Go to **Certificates & secrets > Client secrets > New client secret**
2. Add a description and choose an expiration
3. Click **Add** and copy the **Value** immediately (it won't be shown again)

## 3. Configure API Permissions (Optional)

If you want to use a custom scope:

1. Go to **Expose an API > Add a scope**
2. Set the Application ID URI if prompted
3. Define a scope (e.g., `webhooks.receive`)

For basic Client Credentials flow without custom scopes, use the `.default` scope.

## 4. Find Your Endpoints

From the app's **Overview** page, click **Endpoints**:

- **Token URL:** `https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token`
- **JWKS URI:** `https://login.microsoftonline.com/{TENANT_ID}/discovery/v2.0/keys`
- **Issuer:** `https://login.microsoftonline.com/{TENANT_ID}/v2.0`

Find your Tenant ID on the Overview page under "Directory (tenant) ID".

## 5. Update .env

```bash
OAUTH_TOKEN_URL=https://login.microsoftonline.com/YOUR_TENANT_ID/oauth2/v2.0/token
OAUTH_CLIENT_ID=your_entra_application_id
OAUTH_CLIENT_SECRET=your_client_secret_value
OAUTH_AUDIENCE=
OAUTH_SCOPE=api://YOUR_APPLICATION_ID/.default
OAUTH_JWKS_URI=https://login.microsoftonline.com/YOUR_TENANT_ID/discovery/v2.0/keys
OAUTH_ISSUER=https://login.microsoftonline.com/YOUR_TENANT_ID/v2.0
```

## Notes

- Entra requires the `scope` parameter in the token request. Use `api://{APPLICATION_ID}/.default` for Client Credentials flow.
- Client secrets expire — set a calendar reminder to rotate before expiry.
- Token lifetime defaults to 1 hour (60-90 minutes). Configure via [Token lifetime policies](https://learn.microsoft.com/en-us/entra/identity-platform/configurable-token-lifetimes).
