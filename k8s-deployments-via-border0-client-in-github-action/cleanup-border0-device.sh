#!/usr/bin/env bash
set -euo pipefail

# Default API endpoint if not set
BORDER0_API_URL="${BORDER0_API_URL:-https://api.border0.com/api/v1}"

if [ -z "${BORDER0_TOKEN:-}" ]; then
  echo "Error: BORDER0_TOKEN is not set"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: 'jq' is required but not installed"
  exit 1
fi

DEVICE_ID=$(border0 node state show --json | jq -r .device_id)

if [ -z "$DEVICE_ID" ] || [ "$DEVICE_ID" = "null" ]; then
  echo "No device ID found, skipping cleanup"
  exit 0
fi

echo "Border0 dashboard: https://portal.border0.com/devices/$DEVICE_ID"

echo "Stopping border0-device service..."
service border0-device stop || true

echo "Calling DELETE on ${BORDER0_API_URL}/devices/${DEVICE_ID}"
curl -s -w "\nHTTP status: %{http_code}\n" -X DELETE \
  -H "accept: application/json" \
  -H "x-access-token: ${BORDER0_TOKEN}" \
  "${BORDER0_API_URL}/devices/${DEVICE_ID}"
exit 0