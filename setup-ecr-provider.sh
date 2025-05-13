#!/bin/bash
# setup-ecr-provider.sh
# Usage: sudo ./setup-ecr-provider.sh <AWS_ACCESS_KEY_ID> <AWS_SECRET_ACCESS_KEY> <ECR_IMAGE_URI>

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: sudo $0 <AWS_ACCESS_KEY_ID> <AWS_SECRET_ACCESS_KEY> <ECR_IMAGE_URI>"
  exit 1
fi

AWS_ACCESS_KEY_ID="$1"
AWS_SECRET_ACCESS_KEY="$2"
TEST_IMAGE="${3%\"}"
TEST_IMAGE="${TEST_IMAGE#\"}"
AWS_REGION="us-east-1"

log() { echo "[INFO]  $(date '+%F %T') $*"; }
err() { echo "[ERROR] $*" >&2; exit 1; }

install_deps() {
  log "Installing AWS CLI & jq if missing..."
  apt-get update -y
  apt-get install -y unzip curl jq
  if ! command -v aws >/dev/null; then
    curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o aws.zip
    unzip -q aws.zip && ./aws/install
    rm -rf aws aws.zip
    log "AWS CLI installed."
  fi
}

configure_aws_cli() {
  log "Writing AWS creds for root..."
  mkdir -p /root/.aws
  cat >/root/.aws/credentials <<EOF
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
EOF
  cat >/root/.aws/config <<EOF
[default]
region = $AWS_REGION
output = json
EOF
  aws sts get-caller-identity >/dev/null || err "Invalid AWS credentials"
}

create_provider_yaml() {
  log "Creating /etc/kubernetes/credential-provider.yaml..."
  mkdir -p /etc/kubernetes
  cat >/etc/kubernetes/credential-provider.yaml <<EOF
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
}

create_provider_script() {
  log "Creating credential-provider script..."
  mkdir -p /etc/kubernetes/credential-provider-bin
  cat >/etc/kubernetes/credential-provider-bin/ecr-credential-provider <<'EOF'
#!/bin/bash
set -e
AWS_REGION="us-east-1"
REQUEST=$(cat)
REGISTRY_URL=$(echo "$REQUEST" | jq -r '.image')
if [[ -z "$REGISTRY_URL" || "$REGISTRY_URL" == "null" ]]; then
  echo "Error: No image URL provided" >&2; exit 1
fi
REGISTRY_DOMAIN=$(echo "$REGISTRY_URL" | awk -F/ '{print $1}')
PASSWORD=$(aws ecr get-login-password --region "$AWS_REGION")
if [[ -z "$PASSWORD" ]]; then
  echo "Error: Failed to get ECR login password" >&2; exit 1
fi
cat <<JSON
{
  "kind":"CredentialProviderResponse",
  "apiVersion":"credentialprovider.kubelet.k8s.io/v1",
  "cacheKeyType":"Registry",
  "cacheDuration":"0s",
  "auth": {
    "$REGISTRY_DOMAIN": {"username":"AWS","password":"$PASSWORD"}
  }
}
JSON
EOF
  chmod +x /etc/kubernetes/credential-provider-bin/ecr-credential-provider
}

patch_k3s_execstart() {
  log "Patching /etc/systemd/system/k3s.service ExecStart..."

  local SVC=/etc/systemd/system/k3s.service
  cp "$SVC" "${SVC}.bak"

  awk -v yaml="/etc/kubernetes/credential-provider.yaml" -v bin="/etc/kubernetes/credential-provider-bin" '
    BEGIN { in_block=0 }
    # detect original ExecStart line
    /^ExecStart=\/usr\/local\/bin\/k3s/ {
      in_block=1
      # print our replacement block
      print "ExecStart=/usr/local/bin/k3s \\"
      print "    server \\"
      print "        '\''--disable=traefik'\'' \\"
      print "        --kubelet-arg=image-credential-provider-config=" yaml " \\"
      print "        --kubelet-arg=image-credential-provider-bin-dir=" bin
      next
    }
    # skip old ExecStart block lines (those starting with space) when in_block
    in_block && /^[[:space:]]/ { next }
    # exit block when non-indented line encountered
    in_block { in_block=0 }
    # print all other lines
    { print }
  ' "$SVC" > "${SVC}.new"

  mv "${SVC}.new" "$SVC"
  chmod 644 "$SVC"

  systemctl daemon-reload
  systemctl restart k3s
  log "k3s.service patched and restarted."
}

verify_provider() {
  log "Verifying credential-provider with image: $TEST_IMAGE"
  echo "{\"image\":\"$TEST_IMAGE\"}" | /etc/kubernetes/credential-provider-bin/ecr-credential-provider \
    && log "Provider verification succeeded." \
    || err "Provider verification failed."
}

main() {
  install_deps
  configure_aws_cli
  create_provider_yaml
  create_provider_script
  patch_k3s_execstart
  verify_provider
  log "✅ ECR credential-provider configured successfully."
}

main
