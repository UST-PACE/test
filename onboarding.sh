#!/bin/bash

set -euo pipefail

# ---------- Logging ----------
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1"
}

# ---------- Input Parameters ----------
VPN_USERNAME=""
VPN_PASSWORD=""
VPN_AUTH_FILE=""
VPN_CONFIG_PATH=""
RANCHER_CLUSTER_URL=""

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --vpn-username=*) VPN_USERNAME="${1#*=}" ;;
        --vpn-password=*) VPN_PASSWORD="${1#*=}" ;;
        --vpn-auth-file=*) VPN_AUTH_FILE="${1#*=}" ;;
        --vpn-config-path=*) VPN_CONFIG_PATH="${1#*=}" ;;
        --rancher-cluster-url=*) RANCHER_CLUSTER_URL="${1#*=}" ;;
        *) log "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# ---------- Validation ----------
if [[ -z "$VPN_USERNAME" || -z "$VPN_PASSWORD" || -z "$VPN_AUTH_FILE" || -z "$VPN_CONFIG_PATH" || -z "$RANCHER_CLUSTER_URL" ]]; then
    log "Error: Missing required arguments."
    exit 1
fi

# ---------- Functions ----------
install_openvpn() {
    log "Installing OpenVPN and unzip..."
    sudo apt-get update -y
    sudo apt-get install -y openvpn unzip
}

configure_vpn_auth() {
    log "Storing VPN credentials to $VPN_AUTH_FILE"
    echo -e "$VPN_USERNAME\n$VPN_PASSWORD" | sudo tee "$VPN_AUTH_FILE" > /dev/null
    sudo chmod 600 "$VPN_AUTH_FILE"

    if ! grep -qxF "auth-user-pass $VPN_AUTH_FILE" "$VPN_CONFIG_PATH"; then
        echo "auth-user-pass $VPN_AUTH_FILE" | sudo tee -a "$VPN_CONFIG_PATH" > /dev/null
    fi
}

setup_vpn_service() {
    log "Creating OpenVPN systemd service..."
    sudo tee /etc/systemd/system/openvpn-custom.service > /dev/null <<EOF
[Unit]
Description=Custom OpenVPN Service
After=network.target

[Service]
ExecStart=/usr/sbin/openvpn --config $VPN_CONFIG_PATH
WorkingDirectory=/home/ubuntu
Restart=always
RestartSec=5
KillMode=process
StandardOutput=file:/home/ubuntu/openvpn.log
StandardError=file:/home/ubuntu/openvpn.log

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable openvpn-custom.service
    sudo systemctl start openvpn-custom.service
    sudo systemctl status openvpn-custom.service --no-pager || true
}

get_vpn_ip() {
    log "Retrieving VPN tunnel IP..."
    sleep 5
    VPN_IP=$(ip -4 addr show tun0 2>/dev/null | grep -oP "(?<=inet\s)\d+(\.\d+){3}" || true)
    if [[ -z "$VPN_IP" ]]; then
        log "Error: VPN connection failed."
        exit 1
    fi
    log "VPN IP is $VPN_IP"
}

install_k3s() {
    log "Installing K3s with VPN IP..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=$VPN_IP --disable=traefik" sh -
    sudo chmod 644 /etc/rancher/k3s/k3s.yaml
}

install_kubectl() {
    if ! command -v kubectl &>/dev/null; then
        log "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    else
        log "kubectl already installed"
    fi
}

register_rancher_cluster() {
    log "Registering the cluster with Rancher..."
    kubectl apply -f "$RANCHER_CLUSTER_URL"
}

disable_tls_verification() {
    log "Disabling TLS verification for cluster agent..."
    kubectl patch deployment.apps/cattle-cluster-agent -n cattle-system --type json -p='[{"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name": "STRICT_VERIFY", "value": "false"}}]'
}

configure_dns() {
    log "Configuring custom DNS resolver..."
    sudo mkdir -p /etc/systemd/resolved.conf.d
    echo -e "[Resolve]\nDNS=10.43.0.10\nDNSDomain=~rancher.test.ustpace.com" | sudo tee /etc/systemd/resolved.conf.d/vc.conf > /dev/null
    sudo systemctl restart systemd-resolved
}

install_longhorn() {
    log "Installing Open-iSCSI and deploying Longhorn..."
    sudo apt-get install -y open-iscsi
    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.6.0/deploy/longhorn.yaml
}

# ---------- Main Execution ----------
log "Starting VPN/K3s Onboarding Script"

install_openvpn
configure_vpn_auth
setup_vpn_service
get_vpn_ip
install_k3s
install_kubectl
register_rancher_cluster
disable_tls_verification
configure_dns
install_longhorn

log "Settingup OpenVpn, installing k3s and registering k3s cluster in rancher completed. Check Rancher UI for device status."
