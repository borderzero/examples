<?php
/**
 * Middleware Example for Border0 Signature Verification
 *
 * This demonstrates how to integrate signature verification
 * as middleware in a PHP application.
 */

require_once 'verify_signature.php';

/**
 * Signature verification middleware
 *
 * @param string $jwksUrl URL to JWKS endpoint
 * @return void Exits with 401 if verification fails
 */
function signatureMiddleware($jwksUrl)
{
    static $verifier = null;
    static $lastFetch = 0;
    static $cacheTTL = 300; // Refresh JWKS every 5 minutes

    try {
        // Initialize or refresh verifier
        $now = time();
        if ($verifier === null || ($now - $lastFetch) > $cacheTTL) {
            $verifier = new SignatureVerifier($jwksUrl);
            $verifier->loadPublicKeysFromJWKS();
            $lastFetch = $now;
            error_log("JWKS loaded/refreshed from {$jwksUrl}");
        }

        // Verify current request
        $result = $verifier->verifyCurrentRequest();

        if (!$result['success']) {
            // Log failure
            error_log("✗ Signature verification failed: {$result['message']}");

            // Return 401 Unauthorized
            header('HTTP/1.1 401 Unauthorized');
            header('Content-Type: application/json');
            echo json_encode([
                'error' => 'Unauthorized',
                'message' => $result['message']
            ]);
            exit(1);
        }

        // Log success
        $kid = $result['kid'] ?? 'unknown';
        $timestamp = $_SERVER['HTTP_X_AUTH_TIMESTAMP'] ?? 'unknown';
        $requestId = $_SERVER['HTTP_X_AUTH_REQUEST_ID'] ?? 'unknown';
        error_log("✓ Signature verified [KID: {$kid}, Timestamp: {$timestamp}, RequestID: {$requestId}]");

        // Add verified auth info to request for downstream use
        $_SERVER['AUTH_VERIFIED'] = true;
        $_SERVER['AUTH_KID'] = $kid;

    } catch (Exception $e) {
        error_log("Signature verification error: {$e->getMessage()}");
        header('HTTP/1.1 500 Internal Server Error');
        header('Content-Type: application/json');
        echo json_encode([
            'error' => 'Internal Server Error',
            'message' => 'Signature verification failed'
        ]);
        exit(1);
    }
}

// ============================================================================
// Example Application with Middleware
// ============================================================================

// Apply signature verification middleware
signatureMiddleware('https://signing.border0.io/keys');

// If we reach here, the signature was verified successfully!

// Your application code goes here
header('Content-Type: application/json');
echo json_encode([
    'status' => 'success',
    'message' => 'Hello! Your request signature was verified successfully.',
    'method' => $_SERVER['REQUEST_METHOD'],
    'path' => $_SERVER['REQUEST_URI'],
    'auth' => [
        'kid' => $_SERVER['HTTP_X_AUTH_KID'] ?? null,
        'email' => $_SERVER['HTTP_X_AUTH_EMAIL'] ?? null,
        'name' => $_SERVER['HTTP_X_AUTH_NAME'] ?? null,
        'subject' => $_SERVER['HTTP_X_AUTH_SUBJECT'] ?? null,
        'timestamp' => $_SERVER['HTTP_X_AUTH_TIMESTAMP'] ?? null,
        'request_id' => $_SERVER['HTTP_X_AUTH_REQUEST_ID'] ?? null,
    ]
]);
