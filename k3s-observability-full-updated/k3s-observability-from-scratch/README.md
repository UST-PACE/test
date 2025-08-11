# k3s-observability (From Scratch)

This package contains a ready-to-run observability stack for K3s (Prometheus + OpenTelemetry Collector metrics+logs) configured to forward to Grafana Cloud via OTLP HTTP.

**What is included**
- Helmfiles + Helm values for Prometheus and OpenTelemetry Collector (metrics + logs)
- Kubernetes namespace manifests and a secret template for Grafana Cloud credentials
- Helper scripts to install prerequisites and deploy


**Important**: Update `k8s/secret-templates/otel-collector-creds.yaml` with your Grafana Cloud credentials before running `scripts/deploy.sh`.

**Deploy**:

```bash
# Make executable
chmod +x scripts/*.sh

# Install prerequisites (helm/helmfile)
./scripts/install-prereqs.sh

# Edit k8s/secret-templates/otel-collector-creds.yaml and put your credentials

# Deploy stack
./scripts/deploy.sh
```

**Enable kube-apiserver metrics on K3s (if not already):**
K3s may not expose kube-apiserver metrics by default. On the K3s server, edit the systemd drop-in or service args to pass:

```
--kube-apiserver-arg="profiling=true"
--kube-apiserver-arg="enable-aggregator-routing=true"
```

Then restart k3s: `sudo systemctl restart k3s`

**Verify**:
`kubectl -n otelcol port-forward svc/otelcol 12345:12345 &` then `curl -s "http://127.0.0.1:12345/prometheus/api/v1/targets" | jq .`
