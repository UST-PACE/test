#!/bin/bash
# OpenVPN AS + Let's Encrypt full install & HTTPS setup

set -euo pipefail
LOG_FILE="/var/log/openvpn_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

DOMAIN="vpn.cicd.rest"
EMAIL="your@email.com"
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
OPENVPN_CERT_DIR="/usr/local/openvpn_as/etc/web-ssl"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

error_exit() {
    log "❌ ERROR: $1"
    exit 1
}

log "🚀 Starting OpenVPN AS installation..."

# Cleanup old repo if needed
rm -f /usr/share/keyrings/openvpn-as-repo-public.gpg /etc/apt/sources.list.d/openvpn-as.list

# Add OpenVPN repo
log "🔑 Importing GPG key..."
curl -fsSL https://as-repository.openvpn.net/as-repo-public.gpg | gpg --dearmor -o /usr/share/keyrings/openvpn-as-repo-public.gpg

OS_CODENAME=$(lsb_release -cs)
echo "deb [signed-by=/usr/share/keyrings/openvpn-as-repo-public.gpg] https://as-repository.openvpn.net/as/debian $OS_CODENAME main" > /etc/apt/sources.list.d/openvpn-as.list

log "🔄 Updating apt packages..."
apt update

log "📦 Installing OpenVPN Access Server..."
apt install -y openvpn-as

# Ensure openvpn user exists
if ! id "openvpn" &>/dev/null; then
    log "👤 Creating 'openvpn' user..."
    groupadd openvpn
    useradd -r -g openvpn openvpn
fi

# Stop OpenVPN to free port 80 for Certbot
log "🛑 Stopping OpenVPN temporarily for Certbot..."
systemctl stop openvpnas

# Install certbot & request Let's Encrypt cert
log "🔐 Installing Certbot and requesting certificate..."
apt install -y certbot
certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"

# Start OpenVPN again so sacli can run properly
log "🚀 Restarting OpenVPN Access Server after cert request..."
systemctl start openvpnas
sleep 25  # Give it a moment to fully start

# Copy certs to OpenVPN dir
log "📄 Copying certs..."
cp "$CERT_DIR/fullchain.pem" "$OPENVPN_CERT_DIR/server.crt"
cp "$CERT_DIR/privkey.pem" "$OPENVPN_CERT_DIR/server.key"
chown openvpn:openvpn "$OPENVPN_CERT_DIR/server."*
chmod 600 "$OPENVPN_CERT_DIR/server."*

# Apply cert via sacli (requires OpenVPN to be running)
log "🔧 Applying cert using sacli..."
/usr/local/openvpn_as/scripts/sacli --key "cs.priv_key" --value_file "$OPENVPN_CERT_DIR/server.key" ConfigPut
/usr/local/openvpn_as/scripts/sacli --key "cs.cert" --value_file "$OPENVPN_CERT_DIR/server.crt" ConfigPut

# Restart one last time to apply HTTPS
log "🔄 Restarting OpenVPN AS to finalize HTTPS setup..."
/usr/local/openvpn_as/scripts/sacli start

log "✅ OpenVPN Access Server is now running with Let's Encrypt HTTPS!"
