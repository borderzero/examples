# Go HTTP Signature Verification

## Run

```bash
go run main.go --jwks_url https://signing.border0.io/keys
```

Server listens on `:8080` and verifies Ed25519 signatures on all requests.

## Usage

```go
// Load keys from JWKS
publicKeys, _ := loadPublicKeysFromJWKS("https://signing.border0.io/keys")

// Create handler
handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
    w.Write([]byte("Authenticated!"))
})

// Wrap with verification middleware
verified := verifyingMiddleware(publicKeys, handler)

// Start server
http.ListenAndServe(":8080", verified)
```

Keys are looked up by `X-Auth-Kid` header from the JWKS.
