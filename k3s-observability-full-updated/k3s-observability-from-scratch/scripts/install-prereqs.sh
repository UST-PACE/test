#!/usr/bin/env bash
set -euo pipefail

# Installs helm and helmfile on Ubuntu (no-op if already present)
if ! command -v helm >/dev/null 2>&1; then
  echo "Installing helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

if ! command -v helmfile >/dev/null 2>&1; then
  echo "Installing helmfile..."
  ARCH=$(uname -m)
  if [ "$ARCH" = "x86_64" ]; then
    curl -LO https://github.com/roboll/helmfile/releases/latest/download/helmfile_linux_amd64
    chmod +x helmfile_linux_amd64
    sudo mv helmfile_linux_amd64 /usr/local/bin/helmfile
  else
    echo "Please install helmfile manually for arch $ARCH"
    exit 1
  fi
fi

echo "Ensure kubectl is configured to talk to your k3s cluster."
