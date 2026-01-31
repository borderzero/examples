# HTTP Signature Verification

Verify Ed25519 signatures on HTTP requests signed by Border0/OpenResty.

## Go

```bash
cd go
go run main.go --jwks_url https://signing.staging.border0.io/keys
```

Server runs on `:8080` and verifies all incoming requests.

## PHP

```bash
cd php
php -S localhost:8080 middleware_example.php
```

All requests are verified before processing.

## How It Works

Verifies signatures over: `METHOD\nPATH\nQUERY\nHEADERS`

**Required headers:**
- `X-Auth-Sig` - The signature
- `X-Auth-Kid` - Key ID to lookup public key
- `X-Auth-Timestamp`, `X-Auth-Request-Id`, `X-Auth-Email`, etc.

**Verification:**
1. Extract `X-Auth-Kid` from request
2. Lookup public key in JWKS
3. Build canonical request string
4. Verify Ed25519 signature

Both implementations use the same format and work identically.
