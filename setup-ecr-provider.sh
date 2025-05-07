#!/bin/bash

set -euo pipefail

# Variables
AWS_REGION="us-east-1"
OUTPUT_FORMAT="json"
K3S_SERVICE="/etc/systemd/system/k3s.service"
CREDENTIAL_PROVIDER_YAML="/etc/kubernetes/credential-provider.yaml"
CREDENTIAL_PROVIDER_BIN_DIR="/etc/kubernetes/credential-provider-bin"
CREDENTIAL_PROVIDER_BIN="$CREDENTIAL_PROVIDER_BIN_DIR/ecr-credential-provider"

# Logging
log() {
    echo -e "[INFO] $(date '+%F %T') $*"
}

error_exit() {
    echo -e "[ERROR] $(date '+%F %T') $*" >&2
    exit 1
}

# Step 1: Install AWS CLI
install_aws_cli() {
    log "Installing AWS CLI..."
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    sudo apt-get update -y
    sudo apt-get install unzip -y
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws
    log "AWS CLI installed."
}

# Step 2: Configure AWS credentials
configure_aws() {
    log "Configuring AWS credentials..."
    read -rp "AWS Access Key ID: " access_key
    read -rsp "AWS Secret Access Key: " secret_key && echo
    aws configure set aws_access_key_id "$access_key"
    aws configure set aws_secret_access_key "$secret_key"
    aws configure set region "$AWS_REGION"
    aws configure set output "$OUTPUT_FORMAT"
    log "AWS credentials configured."
}

# Step 3: Verify AWS identity
verify_aws() {
    log "Verifying AWS identity..."
    aws sts get-caller-identity >/dev/null || error_exit "AWS authentication failed."
    log "AWS identity verified."
}

# Step 4: Enable Kubelet credential provider in K3s
enable_kubelet_credential_provider() {
    log "Enabling kubelet credential provider in K3s..."

    sudo mkdir -p /etc/systemd/system/k3s.service.d
    sudo tee /etc/systemd/system/k3s.service.d/override.conf >/dev/null <<EOF
[Service]
Environment="KUBELET_EXTRA_ARGS=--image-credential-provider-config=$CREDENTIAL_PROVIDER_YAML --image-credential-provider-bin-dir=$CREDENTIAL_PROVIDER_BIN_DIR"
EOF

    sudo systemctl daemon-reload
    sudo systemctl restart k3s

    log "K3s credential provider configured."
}

# Step 5: Create Credential Provider Config (no bin line)
create_credential_provider_config() {
    log "Creating credential provider config..."
    sudo mkdir -p "$(dirname "$CREDENTIAL_PROVIDER_YAML")"
    sudo tee "$CREDENTIAL_PROVIDER_YAML" >/dev/null <<EOF
apiVersion: kubelet.config.k8s.io/v1
kind: CredentialProviderConfig
providers:
  - name: ecr-credential-provider
    matchImages:
      - "*.dkr.ecr.*.amazonaws.com"
    defaultCacheDuration: "0s"
    apiVersion: credentialprovider.kubelet.k8s.io/v1
    args:
      - get-credentials
    env:
      - name: AWS_REGION
        value: "$AWS_REGION"
EOF
    log "Credential provider config created."
}

# Step 6: Create Credential Provider Script
create_credential_provider_script() {
    log "Creating credential provider script..."
    sudo mkdir -p "$CREDENTIAL_PROVIDER_BIN_DIR"
    sudo tee "$CREDENTIAL_PROVIDER_BIN" >/dev/null <<'EOF'
#!/bin/bash
AWS_REGION="${AWS_REGION:-us-east-1}"

REQUEST=$(cat)
REGISTRY_URL=$(echo "$REQUEST" | jq -r '.image')

if [[ "$REGISTRY_URL" == "null" ]]; then
  echo "Error: No image URL provided to credential provider" >&2
  exit 1
fi

REGISTRY_DOMAIN=$(echo "$REGISTRY_URL" | awk -F/ '{print $1}')
PASSWORD=$(aws ecr get-login-password --region "$AWS_REGION")

if [[ -z "$PASSWORD" ]]; then
  echo "Error: Failed to get ECR login password" >&2
  exit 1
fi

cat <<JSON
{
  "kind": "CredentialProviderResponse",
  "apiVersion": "credentialprovider.kubelet.k8s.io/v1",
  "cacheKeyType": "Registry",
  "cacheDuration": "0s",
  "auth": {
    "$REGISTRY_DOMAIN": {
      "username": "AWS",
      "password": "$PASSWORD"
    }
  }
}
JSON
EOF

    sudo chmod +x "$CREDENTIAL_PROVIDER_BIN"
    log "Credential provider script created."
}

# Step 7: Verify Credential Provider Script
verify_provider_script() {
    local image="$1"

    if [[ -z "$image" ]]; then
        error_exit "No image provided for credential provider verification. Pass an ECR image name."
    fi

    log "Verifying credential provider script using image: $image"

    echo "{\"image\": \"$image\"}" | "$CREDENTIAL_PROVIDER_BIN" >/dev/null \
        || error_exit "Credential provider script test failed."

    log "Credential provider script verified."
}

# Step 8: Patch k3s ExecStart (optional)
patch_k3s_execstart() {
    log "Patching k3s ExecStart if needed..."

    if ! grep -q "image-credential-provider" "$K3S_SERVICE"; then
        sudo sed -i "/^ExecStart=/c\ExecStart=/usr/local/bin/k3s \\\n    server \\\n    --disable=traefik \\\n    --kubelet-arg=image-credential-provider-config=$CREDENTIAL_PROVIDER_YAML \\\n    --kubelet-arg=image-credential-provider-bin-dir=$CREDENTIAL_PROVIDER_BIN_DIR" "$K3S_SERVICE"
        sudo systemctl daemon-reload
        sudo systemctl restart k3s
        log "K3s service patched."
    else
        log "K3s ExecStart already includes credential provider args."
    fi
}

# Step 9: Validate K3s args
final_validation() {
    log "Validating K3s process..."
    ps aux | grep '[k]3s' | grep 'credential-provider' || error_exit "K3s not running with credential provider args."
    log "K3s credential provider setup looks good."
}

# ========== MAIN ==========
main() {
    install_aws_cli
    configure_aws
    verify_aws
    enable_kubelet_credential_provider
    create_credential_provider_config
    create_credential_provider_script

    local test_image=""
    read -rp "Enter test ECR image (e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com/app:tag): " test_image
    verify_provider_script "$test_image"

    patch_k3s_execstart
    final_validation

    log "✅ All done! ECR credential provider is set up and verified."
}

main "$@"
