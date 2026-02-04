# PHP HTTP Signature Verification

## Requirements

- PHP 7.2+
- `sodium` extension (check with `php -m | grep sodium`)

## Run

```bash
php -S localhost:8080 middleware_example.php
```

All requests are verified before processing.

## Usage

```php
<?php
require_once 'verify_signature.php';

// Initialize with JWKS URL
$verifier = new SignatureVerifier('https://signing.border0.io/keys');
$verifier->loadPublicKeysFromJWKS();

// Verify current request
$result = $verifier->verifyCurrentRequest();

if ($result['success']) {
    echo "Authenticated!";
} else {
    http_response_code(401);
    echo $result['message'];
}
```

Keys are looked up by `X-Auth-Kid` header from the JWKS.

## Files

- `verify_signature.php` - Core verification class
- `middleware_example.php` - Ready-to-use middleware with caching
