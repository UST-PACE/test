#!/bin/bash
# final one with Let's Encrypt HTTPS setup
LOG_FILE="/var/log/openvpn_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

error_exit() {
    log "❌ ERROR: $1"
    exit 1
}

log "🚀 Starting OpenVPN Access Server installation..."

# Remove old repo and key files
sudo rm -f /usr/share/keyrings/openvpn-as-repo-public.gpg /etc/apt/sources.list.d/openvpn-as.list

log "🔑 Importing OpenVPN GPG key..."
sudo curl -fsSL https://as-repository.openvpn.net/as-repo-public.gpg | sudo gpg --dearmor -o /usr/share/keyrings/openvpn-as-repo-public.gpg || error_exit "Failed to import GPG key."

# Verify GPG key
if ! gpg --quiet --import-options import-show /usr/share/keyrings/openvpn-as-repo-public.gpg | grep -q "Access Server"; then
    error_exit "GPG key verification failed!"
fi

# Get OS codename and configure repository
OS_CODENAME=$(lsb_release -cs)
echo "deb [signed-by=/usr/share/keyrings/openvpn-as-repo-public.gpg] https://as-repository.openvpn.net/as/debian $OS_CODENAME main" | sudo tee /etc/apt/sources.list.d/openvpn-as.list

log "🔄 Updating package lists..."
sudo apt update || error_exit "Failed to update package lists."

log "📦 Installing OpenVPN Access Server..."
sudo apt install -y openvpn-as || error_exit "OpenVPN Access Server installation failed."

# Restart and enable OpenVPN Access Server
log "🔄 Restarting OpenVPN Access Server..."
sudo systemctl restart openvpnas && sudo systemctl enable openvpnas || error_exit "Failed to restart OpenVPN Access Server."

# HTTPS Setup with Let's Encrypt certificate
DOMAIN="vpn.cicd.rest"
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
OPENVPN_CERT_DIR="/usr/local/openvpn_as/etc/web-ssl"

if [ -d "$CERT_DIR" ]; then
    log "🔒 Copying Let's Encrypt certificate to OpenVPN..."
    sudo cp "$CERT_DIR/fullchain.pem" "$OPENVPN_CERT_DIR/server.crt" || error_exit "Failed to copy fullchain.pem"
    sudo cp "$CERT_DIR/privkey.pem" "$OPENVPN_CERT_DIR/server.key" || error_exit "Failed to copy privkey.pem"
    sudo chown openvpn:openvpn "$OPENVPN_CERT_DIR/server."* && sudo chmod 600 "$OPENVPN_CERT_DIR/server."*

    log "🔧 Applying certificate to OpenVPN Access Server..."
    sudo /usr/local/openvpn_as/scripts/sacli --key "cs.priv_key" --value_file "$OPENVPN_CERT_DIR/server.key" ConfigPut || error_exit "Failed to set private key"
    sudo /usr/local/openvpn_as/scripts/sacli --key "cs.cert" --value_file "$OPENVPN_CERT_DIR/server.crt" ConfigPut || error_exit "Failed to set cert"
    sudo /usr/local/openvpn_as/scripts/sacli start || error_exit "Failed to restart OpenVPN service"
    log "✅ HTTPS with Let's Encrypt successfully applied to OpenVPN"
else
    log "⚠️ Certificate directory not found: $CERT_DIR. Skipping HTTPS setup."
fi

log "✅ OpenVPN Access Server installation completed successfully!"
