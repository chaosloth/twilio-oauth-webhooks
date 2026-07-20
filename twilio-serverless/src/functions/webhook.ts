import "@twilio-labs/serverless-runtime-types";
import {
  Context,
  ServerlessCallback,
  ServerlessFunctionSignature,
  ServerlessEventObject,
} from "@twilio-labs/serverless-runtime-types/types";
import { validateRequest } from "twilio";

type WebhookContext = {
  ACCOUNT_SID: string;
  AUTH_TOKEN: string;
  DOWNSTREAM_URL: string;
  DOWNSTREAM_API_KEY: string;
};

type WebhookEvent = ServerlessEventObject & {
  endpoint?: string;
  request: {
    headers: Record<string, string>;
  };
};

export const handler: ServerlessFunctionSignature<WebhookContext, WebhookEvent> =
  async function (
    context: Context<WebhookContext>,
    event: WebhookEvent,
    callback: ServerlessCallback
  ) {
    const response = new Twilio.Response();

    const downstreamUrl = event.endpoint || context.DOWNSTREAM_URL;
    const apiKey = context.DOWNSTREAM_API_KEY;

    if (!downstreamUrl) {
      response.setStatusCode(500);
      response.setBody({
        error:
          "No downstream URL: pass an 'endpoint' parameter or configure DOWNSTREAM_URL",
      });
      callback(null, response);
      return;
    }

    if (!apiKey) {
      response.setStatusCode(500);
      response.setBody({
        error: "DOWNSTREAM_API_KEY must be configured",
      });
      callback(null, response);
      return;
    }

    const bearerToken = event.request?.headers?.authorization;
    if (!bearerToken || !bearerToken.startsWith("Bearer ")) {
      response.setStatusCode(401);
      response.setBody({ error: "Missing or invalid Authorization header" });
      callback(null, response);
      return;
    }

    // Validate X-Twilio-Signature to confirm the request is from the same account
    const twilioSignature = event.request?.headers?.["x-twilio-signature"];
    if (!twilioSignature) {
      response.setStatusCode(403);
      response.setBody({ error: "Missing X-Twilio-Signature header" });
      callback(null, response);
      return;
    }

    const requestUrl =
      `https://${event.request.headers.host}${event.request.headers["x-forwarded-path"] || "/webhook"}`;

    const { request, endpoint, ...params } = event;
    const isValid = validateRequest(
      context.AUTH_TOKEN,
      twilioSignature,
      requestUrl,
      params as Record<string, string>
    );

    if (!isValid) {
      console.error("Twilio signature validation failed");
      response.setStatusCode(403);
      response.setBody({ error: "Invalid Twilio signature" });
      callback(null, response);
      return;
    }

    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      Authorization: bearerToken,
      "X-API-Key": apiKey,
    };

    try {
      const downstreamResponse = await fetch(downstreamUrl, {
        method: "POST",
        headers,
        body: JSON.stringify(params),
      });

      const responseBody = await downstreamResponse.text();

      response.setStatusCode(downstreamResponse.status);

      const contentType = downstreamResponse.headers.get("content-type");
      if (contentType) {
        response.appendHeader("Content-Type", contentType);
      }

      response.setBody(responseBody);
      callback(null, response);
    } catch (err) {
      console.error("Error forwarding to downstream:", err);
      response.setStatusCode(502);
      response.setBody({ error: "Failed to forward request to downstream" });
      callback(null, response);
    }
  };
