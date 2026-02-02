<?php
/**
 * HTTP Signature Verification for Border0/OpenResty Signed Requests
 *
 * This script verifies Ed25519 signatures on HTTP requests signed by OpenResty.
 * It matches the canonical request format: METHOD\nPATH\nQUERY\nHEADERS
 *
 * Requirements:
 * - PHP 7.2+ with sodium extension enabled
 * - composer require paragonie/sodium_compat (if sodium not available)
 */

class SignatureVerifier
{
    private $publicKeys = [];
    private $jwksUrl;

    /**
     * Headers that are included in the signature
     */
    private const HEADERS_TO_SIGN = [
        'Host',
        'X-Auth-Timestamp',
        'X-Auth-Request-Id',
        'X-Auth-Kid',
        'X-Auth-Email',
        'X-Auth-Name',
        'X-Auth-Picture',
        'X-Auth-Subject',
        'X-Auth-IsServiceAccount',
    ];

    public function __construct($jwksUrl)
    {
        $this->jwksUrl = $jwksUrl;
    }

    /**
     * Load public keys from JWKS endpoint
     *
     * @return bool Success status
     * @throws Exception if JWKS cannot be loaded
     */
    public function loadPublicKeysFromJWKS()
    {
        $response = file_get_contents($this->jwksUrl);
        if ($response === false) {
            throw new Exception("Failed to fetch JWKS from {$this->jwksUrl}");
        }

        $jwks = json_decode($response, true);
        if (!isset($jwks['keys']) || !is_array($jwks['keys'])) {
            throw new Exception("Invalid JWKS format");
        }

        foreach ($jwks['keys'] as $key) {
            // Only support Ed25519 keys (OKP key type with Ed25519 curve)
            if ($key['kty'] === 'OKP' && $key['crv'] === 'Ed25519') {
                $kid = $key['kid'];

                // Decode the base64url-encoded public key
                $publicKeyBytes = $this->base64UrlDecode($key['x']);

                if (strlen($publicKeyBytes) !== SODIUM_CRYPTO_SIGN_PUBLICKEYBYTES) {
                    error_log("Warning: Invalid Ed25519 key length for kid {$kid}");
                    continue;
                }

                $this->publicKeys[$kid] = $publicKeyBytes;
                error_log("Loaded public key with ID: {$kid}");
            }
        }

        if (empty($this->publicKeys)) {
            throw new Exception("No valid Ed25519 keys found in JWKS");
        }

        return true;
    }

    /**
     * Build the canonical request string that was signed
     *
     * @param string $method HTTP method (GET, POST, etc.)
     * @param string $path URL path
     * @param string $query Query string (without leading ?)
     * @param array $headers Associative array of headers
     * @return string Canonical request string
     */
    private function buildCanonicalRequest($method, $path, $query, $headers)
    {
        $headerPairs = [];

        foreach (self::HEADERS_TO_SIGN as $headerName) {
            $headerNameLower = strtolower($headerName);

            // Check for header in case-insensitive way
            $value = null;
            foreach ($headers as $key => $val) {
                if (strtolower($key) === $headerNameLower) {
                    $value = $val;
                    break;
                }
            }

            if ($value !== null) {
                // Handle multi-value headers (arrays)
                if (is_array($value)) {
                    $value = implode(',', $value);
                }

                $headerPairs[] = $headerNameLower . ':' . $value;
            }
        }

        // Sort headers alphabetically
        sort($headerPairs);
        $canonicalHeaders = implode("\n", $headerPairs);

        // Build canonical request: METHOD\nPATH\nQUERY\nHEADERS
        $canonicalRequest = implode("\n", [
            $method,
            $path,
            $query,
            $canonicalHeaders
        ]);

        return $canonicalRequest;
    }

    /**
     * Verify the Ed25519 signature on an HTTP request
     *
     * @param string $method HTTP method
     * @param string $path URL path
     * @param string $query Query string
     * @param array $headers Request headers
     * @return array ['success' => bool, 'message' => string, 'kid' => string]
     */
    public function verifyRequest($method, $path, $query, $headers)
    {
        // Extract signature from X-Auth-Sig header
        $sigB64 = null;
        foreach ($headers as $key => $value) {
            if (strtolower($key) === 'x-auth-sig') {
                $sigB64 = $value;
                break;
            }
        }

        if ($sigB64 === null) {
            return [
                'success' => false,
                'message' => 'Missing X-Auth-Sig header'
            ];
        }

        // Extract kid from X-Auth-Kid header
        $kid = null;
        foreach ($headers as $key => $value) {
            if (strtolower($key) === 'x-auth-kid') {
                $kid = $value;
                break;
            }
        }

        if ($kid === null) {
            return [
                'success' => false,
                'message' => 'Missing X-Auth-Kid header'
            ];
        }

        // Look up public key by kid
        if (!isset($this->publicKeys[$kid])) {
            return [
                'success' => false,
                'message' => "Unknown key ID: {$kid}",
                'kid' => $kid
            ];
        }

        $publicKey = $this->publicKeys[$kid];

        // Decode signature
        $signature = base64_decode($sigB64);
        if ($signature === false || strlen($signature) !== SODIUM_CRYPTO_SIGN_BYTES) {
            return [
                'success' => false,
                'message' => 'Invalid signature encoding',
                'kid' => $kid
            ];
        }

        // Build canonical request
        $canonicalRequest = $this->buildCanonicalRequest($method, $path, $query, $headers);

        // Verify signature using libsodium
        $verified = sodium_crypto_sign_verify_detached(
            $signature,
            $canonicalRequest,
            $publicKey
        );

        if ($verified) {
            return [
                'success' => true,
                'message' => 'Signature verified successfully',
                'kid' => $kid,
                'canonical_request' => $canonicalRequest
            ];
        } else {
            return [
                'success' => false,
                'message' => 'Signature verification failed',
                'kid' => $kid,
                'canonical_request' => $canonicalRequest
            ];
        }
    }

    /**
     * Verify the current HTTP request
     *
     * @return array ['success' => bool, 'message' => string, 'kid' => string]
     */
    public function verifyCurrentRequest()
    {
        $method = $_SERVER['REQUEST_METHOD'];
        $path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
        $query = $_SERVER['QUERY_STRING'] ?? '';

        // Get all headers (Apache and nginx compatible)
        $headers = $this->getAllHeaders();

        return $this->verifyRequest($method, $path, $query, $headers);
    }

    /**
     * Get all request headers in a case-preserving way
     *
     * @return array Associative array of headers
     */
    private function getAllHeaders()
    {
        if (function_exists('getallheaders')) {
            return getallheaders();
        }

        // Fallback for nginx
        $headers = [];
        foreach ($_SERVER as $name => $value) {
            if (substr($name, 0, 5) === 'HTTP_') {
                $headerName = str_replace(' ', '-', ucwords(strtolower(str_replace('_', ' ', substr($name, 5)))));
                $headers[$headerName] = $value;
            }
        }

        // Add Host header if available
        if (isset($_SERVER['HTTP_HOST'])) {
            $headers['Host'] = $_SERVER['HTTP_HOST'];
        }

        return $headers;
    }

    /**
     * Base64 URL decode (RFC 4648)
     *
     * @param string $data Base64url-encoded data
     * @return string Decoded bytes
     */
    private function base64UrlDecode($data)
    {
        $remainder = strlen($data) % 4;
        if ($remainder) {
            $padlen = 4 - $remainder;
            $data .= str_repeat('=', $padlen);
        }
        return base64_decode(strtr($data, '-_', '+/'));
    }
}

// ============================================================================
// Example Usage
// ============================================================================

// Example 1: Verify current HTTP request with JWKS
function verifyWithJWKS()
{
    try {
        $verifier = new SignatureVerifier('https://signing.staging.border0.io/keys');
        $verifier->loadPublicKeysFromJWKS();

        $result = $verifier->verifyCurrentRequest();

        if ($result['success']) {
            header('HTTP/1.1 200 OK');
            echo json_encode([
                'status' => 'authenticated',
                'message' => $result['message'],
                'kid' => $result['kid']
            ]);
        } else {
            header('HTTP/1.1 401 Unauthorized');
            echo json_encode([
                'status' => 'unauthorized',
                'message' => $result['message']
            ]);
        }
    } catch (Exception $e) {
        header('HTTP/1.1 500 Internal Server Error');
        echo json_encode([
            'status' => 'error',
            'message' => $e->getMessage()
        ]);
    }
}

// ============================================================================
// Run the appropriate example based on CLI or web context
// ============================================================================

if (php_sapi_name() === 'cli') {
    // Command line mode - just load to verify syntax
    echo "SignatureVerifier class loaded successfully.\n";
    echo "Use verifyWithJWKS() function or include this file in your application.\n";
} else {
    // Web server mode - verify incoming request
    verifyWithJWKS();
}
