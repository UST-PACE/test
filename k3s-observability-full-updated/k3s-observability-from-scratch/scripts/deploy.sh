#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

echo "Creating namespaces..."
kubectl apply -f k8s/namespaces.yaml

echo "Create otel-collector-creds secret: edit k8s/secret-templates/otel-collector-creds.yaml with real values first."
kubectl apply -f k8s/secret-templates/otel-collector-creds.yaml

echo "Installing helm repos..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts || true
helm repo update

echo "Apply Helmfiles... (this will install Prometheus and OTEL collectors)"
helmfile -f helmfiles/prometheus.yaml apply
helmfile -f helmfiles/otelcol.yaml apply
helmfile -f helmfiles/otelcol-scrape-logs.yaml apply

echo "Done. Check pods in otelcol and prometheus namespaces."
kubectl -n otelcol get pods
kubectl -n prometheus get pods
