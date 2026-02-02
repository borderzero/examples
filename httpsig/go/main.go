package main

import (
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"sort"
	"strings"
)

// JWKKey represents a single key from a JWKS
type JWKKey struct {
	Kty string `json:"kty"`
	Crv string `json:"crv"`
	X   string `json:"x"`
	Kid string `json:"kid"`
}

// JWKS represents a JSON Web Key Set
type JWKS struct {
	Keys []JWKKey `json:"keys"`
}

// loadPublicKeysFromJWKS fetches and parses a JWKS from a URL
// Returns a map of key ID to public key
func loadPublicKeysFromJWKS(jwksURL string) (map[string]ed25519.PublicKey, error) {
	resp, err := http.Get(jwksURL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch JWKS: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("JWKS endpoint returned status %d", resp.StatusCode)
	}

	var jwks JWKS
	if err := json.NewDecoder(resp.Body).Decode(&jwks); err != nil {
		return nil, fmt.Errorf("failed to parse JWKS: %w", err)
	}

	publicKeys := make(map[string]ed25519.PublicKey)
	for _, key := range jwks.Keys {
		// Only support Ed25519 keys (OKP key type with Ed25519 curve)
		if key.Kty == "OKP" && key.Crv == "Ed25519" {
			xBytes, err := base64.RawURLEncoding.DecodeString(key.X)
			if err != nil {
				log.Printf("Warning: failed to decode public key with kid %s: %v", key.Kid, err)
				continue
			}
			if len(xBytes) != 32 {
				log.Printf("Warning: invalid Ed25519 key length for kid %s: %d", key.Kid, len(xBytes))
				continue
			}
			publicKeys[key.Kid] = ed25519.PublicKey(xBytes)
			log.Printf("Loaded public key with ID: %s", key.Kid)
		}
	}

	if len(publicKeys) == 0 {
		return nil, fmt.Errorf("no valid Ed25519 keys found in JWKS")
	}

	return publicKeys, nil
}

// buildCanonicalRequest reconstructs the canonical request string
// that was signed by OpenResty
func buildCanonicalRequest(r *http.Request) (string, error) {
	// OpenResty signs these specific headers (including Host)
	headersToSign := []string{
		"Host",
		"X-Auth-Timestamp",
		"X-Auth-Request-Id",
		"X-Auth-Kid",
		"X-Auth-Email",
		"X-Auth-Name",
		"X-Auth-Picture",
		"X-Auth-Subject",
		"X-Auth-IsServiceAccount",
	}

	headerPairs := make([]string, 0, len(headersToSign))
	for _, headerName := range headersToSign {
		var values []string

		// Host is special in Go - it's in req.Host, not req.Header
		if headerName == "Host" {
			if r.Host != "" {
				values = []string{r.Host}
			}
		} else {
			values = r.Header.Values(headerName)
		}

		if len(values) > 0 {
			nameLower := strings.ToLower(headerName)
			// Handle multi-value headers
			headerPairs = append(
				headerPairs,
				fmt.Sprintf("%s:%s", nameLower, strings.Join(values, ",")),
			)
		}
	}
	sort.Strings(headerPairs)
	canonicalHeaders := strings.Join(headerPairs, "\n")

	// Build canonical request as: METHOD\nPATH\nQUERY\nHEADERS
	// This prevents header transplant attacks by binding signature to specific request
	queryString := r.URL.RawQuery
	if queryString == "" {
		queryString = ""
	}

	canonicalRequest := strings.Join([]string{
		r.Method,
		r.URL.Path,
		queryString,
		canonicalHeaders,
	}, "\n")

	return canonicalRequest, nil
}

// VerifyRequestSignature verifies the Ed25519 signature on an HTTP request
func VerifyRequestSignature(r *http.Request, publicKey ed25519.PublicKey) error {
	// Extract signature from X-Auth-Sig header
	sigB64 := r.Header.Get("X-Auth-Sig")
	if sigB64 == "" {
		return fmt.Errorf("missing X-Auth-Sig header")
	}

	signature, err := base64.StdEncoding.DecodeString(sigB64)
	if err != nil {
		return fmt.Errorf("failed to decode signature: %w", err)
	}

	// Build canonical request (without body to support streaming)
	canonicalRequest, err := buildCanonicalRequest(r)
	if err != nil {
		return fmt.Errorf("failed to build canonical request: %w", err)
	}

	// Verify signature
	if !ed25519.Verify(publicKey, []byte(canonicalRequest), signature) {
		return fmt.Errorf("signature verification failed")
	}

	return nil
}

// verifyingMiddleware is an HTTP middleware that verifies request signatures
// Looks up the key by kid from X-Auth-Kid header
func verifyingMiddleware(publicKeys map[string]ed25519.PublicKey, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		timestamp := r.Header.Get("X-Auth-Timestamp")
		requestID := r.Header.Get("X-Auth-Request-Id")
		kid := r.Header.Get("X-Auth-Kid")

		if kid == "" {
			log.Printf("✗ Signature verification failed: missing X-Auth-Kid header")
			http.Error(w, "Unauthorized: missing X-Auth-Kid header", http.StatusUnauthorized)
			return
		}

		publicKey, exists := publicKeys[kid]
		if !exists {
			log.Printf("✗ Signature verification failed: unknown key ID %s", kid)
			http.Error(w, "Unauthorized: unknown key ID", http.StatusUnauthorized)
			return
		}

		if err := VerifyRequestSignature(r, publicKey); err != nil {
			log.Printf("✗ Signature verification failed for KID %s: %v", kid, err)
			http.Error(w, "Unauthorized: "+err.Error(), http.StatusUnauthorized)
			return
		}

		log.Printf("✓ Signature verified [KID: %s, Timestamp: %s, RequestID: %s]", kid, timestamp, requestID)
		next.ServeHTTP(w, r)
	})
}

func main() {
	jwksURL := flag.String("jwks_url", "", "URL to fetch JWKS (JSON Web Key Set)")
	flag.Parse()

	if *jwksURL == "" {
		fmt.Fprintf(os.Stderr, "Error: --jwks_url is required\n\n")
		fmt.Fprintf(os.Stderr, "Usage:\n")
		fmt.Fprintf(os.Stderr, "  %s --jwks_url <https://example.com/.well-known/jwks.json>\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "\nExample:\n")
		fmt.Fprintf(os.Stderr, "  %s --jwks_url https://signing.staging.border0.io/keys\n", os.Args[0])
		os.Exit(1)
	}

	// Load public keys from JWKS URL
	log.Printf("Fetching JWKS from %s", *jwksURL)
	publicKeys, err := loadPublicKeysFromJWKS(*jwksURL)
	if err != nil {
		log.Fatalf("Failed to load JWKS: %v", err)
	}
	log.Printf("Loaded %d public key(s) from JWKS", len(publicKeys))

	// Create a simple handler
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello! Your request signature was verified successfully.\n")
		fmt.Fprintf(w, "Method: %s\n", r.Method)
		fmt.Fprintf(w, "Path: %s\n", r.URL.Path)
		fmt.Fprintf(w, "X-Auth-Kid: %s\n", r.Header.Get("X-Auth-Kid"))
		fmt.Fprintf(w, "X-Auth-Timestamp: %s\n", r.Header.Get("X-Auth-Timestamp"))
		fmt.Fprintf(w, "X-Auth-Request-Id: %s\n", r.Header.Get("X-Auth-Request-Id"))
	})

	// Wrap handler with signature verification middleware
	verifiedHandler := verifyingMiddleware(publicKeys, handler)

	// Start server
	addr := ":8080"
	log.Printf("Starting server on %s", addr)
	log.Printf("All requests must have valid Ed25519 signatures")
	if err := http.ListenAndServe(addr, verifiedHandler); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
