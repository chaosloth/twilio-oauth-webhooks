package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/MicahParks/keyfunc/v3"
	"github.com/golang-jwt/jwt/v5"
	"github.com/joho/godotenv"
	twilioClient "github.com/twilio/twilio-go/client"
)

var (
	jwks         keyfunc.Keyfunc
	port         string
	issuer       string
	authTokenSecret string
)

func init() {
	// Load .env from working directory (run from project root)
	envPath := ".env"
	if err := godotenv.Load(envPath); err != nil {
		// Fallback: try relative to binary location
		envPath = filepath.Join("..", "..", ".env")
		if err := godotenv.Load(envPath); err != nil {
			log.Printf("Warning: could not load .env file: %v", err)
		}
	}

	port = os.Getenv("WEBHOOK_PORT")
	if port == "" {
		port = "3000"
	}

	jwksURI := os.Getenv("OAUTH_JWKS_URI")
	if jwksURI == "" {
		log.Fatal("OAUTH_JWKS_URI is required in .env")
	}

	issuer = os.Getenv("OAUTH_ISSUER")
	authTokenSecret = os.Getenv("TWILIO_AUTH_TOKEN_SECRET")

	// Initialize JWKS
	var err error
	jwks, err = keyfunc.NewDefaultCtx(context.Background(), []string{jwksURI})
	if err != nil {
		log.Fatalf("Failed to create JWKS: %v", err)
	}

	log.Printf("Webhook server initializing...")
	log.Printf("JWKS URI: %s", jwksURI)
	if issuer != "" {
		log.Printf("Issuer: %s", issuer)
	} else {
		log.Printf("Issuer: (not set)")
	}
}

func validateToken(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Dump raw incoming request
		rawBody, _ := io.ReadAll(r.Body)
		r.Body = io.NopCloser(strings.NewReader(string(rawBody)))

		log.Println("============================================================")
		log.Println("RAW INCOMING REQUEST")
		log.Println("============================================================")
		log.Printf("%s %s %s", r.Method, r.URL.RequestURI(), r.Proto)
		for name, values := range r.Header {
			for _, v := range values {
				log.Printf("%s: %s", name, v)
			}
		}
		log.Println()
		log.Println(string(rawBody))
		log.Println("============================================================")

		authHeader := r.Header.Get("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			log.Println("--- Token validation failed: Missing or invalid Authorization header ---")
			http.Error(w, `{"error":"Missing or invalid Authorization header"}`, http.StatusUnauthorized)
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")

		// Parse and validate the token
		token, err := jwt.Parse(tokenString, jwks.Keyfunc)
		if err != nil {
			log.Printf("--- Token validation failed: %v ---", err)
			http.Error(w, `{"error":"Invalid token"}`, http.StatusUnauthorized)
			return
		}

		if !token.Valid {
			log.Println("--- Token validation failed: token marked invalid ---")
			http.Error(w, `{"error":"Invalid token"}`, http.StatusUnauthorized)
			return
		}

		// Verify issuer if set
		if issuer != "" {
			claims, ok := token.Claims.(jwt.MapClaims)
			if !ok {
				log.Println("--- Token validation failed: could not parse claims ---")
				http.Error(w, `{"error":"Invalid token claims"}`, http.StatusUnauthorized)
				return
			}

			tokenIssuer, ok := claims["iss"].(string)
			if !ok || tokenIssuer != issuer {
				log.Printf("--- Token validation failed: issuer mismatch ---")
				log.Printf("    Token issuer: %s", tokenIssuer)
				log.Printf("    Expected issuer: %s", issuer)
				http.Error(w, `{"error":"Invalid issuer"}`, http.StatusUnauthorized)
				return
			}
		}

		log.Println("--- Token validation successful ---")

		// Store claims and raw body in context for the next handler
		ctx := context.WithValue(r.Context(), "claims", token.Claims)
		ctx = context.WithValue(ctx, "rawBody", rawBody)
		next(w, r.WithContext(ctx))
	}
}

func webhookHandler(w http.ResponseWriter, r *http.Request) {
	claims := r.Context().Value("claims")

	// Parse request body
	var body map[string]interface{}
	contentType := r.Header.Get("Content-Type")

	if strings.Contains(contentType, "application/x-www-form-urlencoded") {
		if err := r.ParseForm(); err != nil {
			log.Printf("Error parsing form: %v", err)
		}
		body = make(map[string]interface{})
		for k, v := range r.Form {
			if len(v) == 1 {
				body[k] = v[0]
			} else {
				body[k] = v
			}
		}
	} else if strings.Contains(contentType, "application/json") {
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			log.Printf("Error parsing JSON: %v", err)
			body = make(map[string]interface{})
		}
	} else {
		body = make(map[string]interface{})
	}

	// Log the webhook
	log.Println("--- Webhook received ---")
	claimsJSON, _ := json.MarshalIndent(claims, "", "  ")
	log.Printf("Token claims: %s", string(claimsJSON))
	bodyJSON, _ := json.MarshalIndent(body, "", "  ")
	log.Printf("Webhook payload: %s", string(bodyJSON))

	// Validate X-Twilio-Signature
	twilioSignature := r.Header.Get("X-Twilio-Signature")
	if authTokenSecret != "" && twilioSignature != "" {
		rawBody, _ := r.Context().Value("rawBody").([]byte)
		requestValidator := twilioClient.NewRequestValidator(authTokenSecret)
		scheme := r.Header.Get("X-Forwarded-Proto")
		if scheme == "" {
			scheme = "https"
		}
		host := r.Header.Get("X-Forwarded-Host")
		if host == "" {
			host = r.Host
		}
		requestURL := scheme + "://" + host + r.URL.Path
		if r.URL.RawQuery != "" {
			requestURL += "?" + r.URL.RawQuery
		}
		isValid := requestValidator.ValidateBody(requestURL, rawBody, twilioSignature)
		if isValid {
			log.Println("--- Signature validation: VALID ---")
		} else {
			log.Println("--- Signature validation: INVALID ---")
		}
	} else if twilioSignature == "" {
		log.Println("--- Signature validation: SKIPPED (no X-Twilio-Signature header) ---")
	} else {
		log.Println("--- Signature validation: SKIPPED (no TWILIO_AUTH_TOKEN_SECRET configured) ---")
	}

	// Determine if Voice or Messaging
	isVoice := body["CallSid"] != nil || body["CallStatus"] != nil

	var twiml string
	if isVoice {
		twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Say>Hello! This webhook is protected by OAuth 2.0.</Say>
</Response>`
	} else {
		twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Message>Hello! This webhook is protected by OAuth 2.0.</Message>
</Response>`
	}

	w.Header().Set("Content-Type", "text/xml")
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, twiml)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, `{"status":"ok"}`)
}

func main() {
	http.HandleFunc("/webhook", validateToken(webhookHandler))
	http.HandleFunc("/health", healthHandler)

	log.Printf("Webhook server listening on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
