#!/bin/bash
set -e

echo "[INFO] Creating K3s systemd override for metrics and profiling..."

sudo mkdir -p /etc/systemd/system/k3s.service.d

cat <<EOF | sudo tee /etc/systemd/system/k3s.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/local/bin/k3s server \
  --kube-controller-manager-arg="bind-address=0.0.0.0" \
  --kube-scheduler-arg="bind-address=0.0.0.0" \
  --kube-apiserver-arg="authorization-mode=Node,RBAC" \
  --kube-apiserver-arg="enable-aggregator-routing=true" \
  --kube-apiserver-arg="profiling=true"
EOF

echo "[INFO] Reloading systemd and restarting K3s..."
sudo systemctl daemon-reload
sudo systemctl restart k3s

echo "[INFO] K3s restarted with metrics endpoints enabled."
