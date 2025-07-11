#!/bin/bash
set -euo pipefail

# === CONFIGURATION ===
WG_INTERFACE="wg0"
WG_DIR="/etc/wireguard"
WG_PRIVATE_KEY_FILE="$WG_DIR/privatekey"
WG_CONF_FILE="$WG_DIR/$WG_INTERFACE.conf"

# === INPUTS ===
WG_LOCAL_IP="${1:-}"
HUB_ENDPOINT="aldochan.com:51820"

if [[ -z "$WG_LOCAL_IP" ]]; then
  echo "Usage: $0 <local_ip | ask about it>"
  exit 1
fi

# === Ensure wireguard-tools is installed ===
if ! command -v wg > /dev/null || ! command -v wg-quick > /dev/null; then
  echo "Installing wireguard-tools..."
  if command -v pacman &> /dev/null; then
    sudo pacman -Sy --noconfirm wireguard-tools
  elif command -v apt &> /dev/null; then
    sudo apt update && sudo apt install -y wireguard
  else
    echo "Package manager not recognized. Install wireguard-tools manually."
    exit 1
  fi
fi

# === Generate keypair if not present ===
echo "[*] Generating private key..."
sudo mkdir -p "$WG_DIR"
if [[ ! -f "$WG_PRIVATE_KEY_FILE" ]]; then
  sudo wg genkey | sudo tee "$WG_PRIVATE_KEY_FILE" > /dev/null
  sudo chmod 600 "$WG_PRIVATE_KEY_FILE"
fi

echo "[*] Generating public key..."
WG_PUBLIC_KEY=$(sudo cat "$WG_PRIVATE_KEY_FILE" | wg pubkey)
echo "[+] Public key: $WG_PUBLIC_KEY"

# === Write WireGuard config ===
echo "[*] Writing $WG_CONF_FILE..."
sudo tee "$WG_CONF_FILE" > /dev/null <<EOF
[Interface]
PrivateKey = $(sudo cat "$WG_PRIVATE_KEY_FILE")
Address = $WG_LOCAL_IP/24

[Peer]
PublicKey = MlofoQqfXgI3AJEO0mjFvA1IwUNBA4yM1+KBjEkubAg=
Endpoint = $HUB_ENDPOINT
AllowedIPs = 10.42.42.1/32, 10.42.42.0/24
PersistentKeepalive = 25
EOF

sudo chmod 600 "$WG_CONF_FILE"

# === Enable and start interface ===
echo "[*] Starting WireGuard interface..."
sudo systemctl enable --now wg-quick@$WG_INTERFACE

# === Done ===
echo "[✓] WireGuard tunnel is up!"
echo "Don't forget to add the following to the hub:"
echo
echo "[Peer]"
echo "PublicKey = $WG_PUBLIC_KEY"
echo "AllowedIPs = $WG_LOCAL_IP/32"

