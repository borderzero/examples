#!/usr/bin/env bash
set -euo pipefail

# This script downloads the Border0 client, installs a Border0 node,
# starts the VPN, checks service status, and debugs peers.

# Ensure running as root
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "Script must be run as root. Try: sudo $0"
  exit 1
fi

echo "Downloading Border0 client..."
curl -fsSL https://download.border0.com/linux_amd64/border0 -o /usr/local/bin/border0
chmod +x /usr/local/bin/border0

if [ -z "${BORDER0_TOKEN:-}" ]; then
  echo "Error: BORDER0_TOKEN is not set."
  exit 1
fi

export BORDER0_TOKEN

echo "Installing Border0 node and starting VPN..."
border0 node install --start-vpn

echo "Waiting for VPN to start..."
sleep 1


echo "Checking border0-device service status..."
service border0-device status

echo "Waiting for VPN to start..."
sleep 10

echo "Debugging Border0 peers..."
border0 node debug peers

echo "show hosts file"
cat /etc/hosts


echo "ready to go!"