Kubernetes manifests in this folder:
- namespaces.yaml: Creates namespaces otelcol and prometheus
- secret-templates/otel-collector-creds.yaml: Template for Grafana Cloud credentials secret. Edit values before applying.
- rbac/prometheus-service-account.yaml: Example SA (Helm chart creates its own by default).
