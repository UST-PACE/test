Got it! Here’s a **comprehensive README.md** for your GitHub repo that documents the entire process of uninstalling the Grafana k8s monitoring stack, dealing with stuck Alloy CRs, and finally cleaning up the terminating namespace.

---

````markdown
# Cleanup Guide: Uninstalling Grafana Kubernetes Monitoring Stack & Resolving Stuck Namespace

This document outlines the step-by-step process to uninstall a Grafana Kubernetes monitoring stack deployed via Helm, clean up stuck custom resources (Alloys), and resolve a Kubernetes namespace stuck in `Terminating` state.

---

## Background

After uninstalling the monitoring stack Helm charts, the `prometheus` namespace remained stuck in the `Terminating` state. Investigation revealed that custom resources of kind `alloy.collectors.grafana.com` with Helm uninstall finalizers were blocking namespace deletion.

---

## Problem Summary

- Helm charts for Grafana k8s monitoring were uninstalled.
- Alloy custom resources (`grafana-k8s-monitoring-alloy-*`) still existed in `prometheus` namespace with the finalizer:  
  `helm.sdk.operatorframework.io/uninstall-release`
- These finalizers prevented the Alloy CRs and consequently the namespace from being deleted.
- Namespace stuck in `Terminating` due to remaining Alloy CRs with finalizers.

---

## Step-by-Step Cleanup Procedure

### 1. List Alloy custom resources in `prometheus` namespace

```bash
kubectl get alloys -n prometheus
````

You should see entries like:

```
NAME                                     AGE
grafana-k8s-monitoring-alloy-logs        43d
grafana-k8s-monitoring-alloy-metrics     43d
grafana-k8s-monitoring-alloy-receiver    43d
grafana-k8s-monitoring-alloy-singleton   43d
```

### 2. Verify Alloy CRs have finalizers blocking deletion

```bash
kubectl get alloys -n prometheus -o json | jq '.items[] | {name: .metadata.name, finalizers: .metadata.finalizers}'
```

Expected output shows finalizer:

```json
{
  "name": "grafana-k8s-monitoring-alloy-logs",
  "finalizers": [
    "helm.sdk.operatorframework.io/uninstall-release"
  ]
}
...
```

### 3. Remove Helm uninstall-release finalizer from Alloy CRs

Run the following script to remove the Helm uninstall finalizer and force Alloy CR deletion:

```bash
NAMESPACE=prometheus

for name in grafana-k8s-monitoring-alloy-logs grafana-k8s-monitoring-alloy-metrics grafana-k8s-monitoring-alloy-receiver grafana-k8s-monitoring-alloy-singleton; do
  echo "Processing Alloy: $name"
  kubectl get alloys "$name" -n $NAMESPACE -o json > "$name".json

  # Remove helm uninstall-release finalizer only
  jq 'del(.metadata.finalizers[] | select(. == "helm.sdk.operatorframework.io/uninstall-release")) as $f |
      .metadata.finalizers |= (if $f == null then [] else . end)' "$name".json > "$name"-nofinalizer.json

  # Force finalize by PATCHing the resource finalizer endpoint
  kubectl replace --raw "/apis/collectors.grafana.com/v1alpha1/namespaces/$NAMESPACE/alloys/$name/finalize" -f "$name"-nofinalizer.json

  echo "Finalizer removed from $name"
done
```

### 4. Confirm Alloy CRs are deleted

```bash
kubectl get alloys -n prometheus
```

The output should now be empty.

---

### 5. Check namespace finalizers and remove if necessary

View current namespace finalizers:

```bash
kubectl get namespace prometheus -o json | jq '.spec.finalizers'
```

If it returns:

```json
[
  "kubernetes"
]
```

Try removing the namespace finalizer:

```bash
kubectl patch namespace prometheus -p '{"metadata":{"finalizers":[]}}' --type=merge
```

---

### 6. Confirm namespace is deleted

```bash
kubectl get namespace prometheus
```

The namespace should no longer be in `Terminating` state or be completely deleted.

---

## Additional Troubleshooting

* List all resources with finalizers blocking deletion in the namespace:

```bash
kubectl api-resources --verbs=list --namespaced -o name | \
xargs -n 1 kubectl get -n prometheus --ignore-not-found -o json | \
jq '.items[] | select(.metadata.finalizers != null) | {kind: .kind, name: .metadata.name, finalizers: .metadata.finalizers}'
```

* Describe namespace for detailed events:

```bash
kubectl describe namespace prometheus
```

* If necessary, force delete namespace by manual finalizer removal in etcd (**use with caution**).

---

## Summary

* Uninstalled Helm charts left Alloy CRs with Helm uninstall finalizers.
* These finalizers blocked Alloy CR deletion and namespace deletion.
* Manually removed the `helm.sdk.operatorframework.io/uninstall-release` finalizer from Alloy CRs using `kubectl replace --raw` API call.
* Removed namespace finalizers to unblock namespace deletion.
* Namespace `prometheus` successfully deleted.

---

## References

* Kubernetes finalizers documentation: [https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/#finalizers](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/#finalizers)
* Helm uninstall finalizer issues: [https://helm.sh/docs/topics/charts\_hooks/#finalizers](https://helm.sh/docs/topics/charts_hooks/#finalizers)
* Kubernetes namespace stuck terminating troubleshooting: [https://kubernetes.io/docs/tasks/administer-cluster/namespaces/#deleting-a-namespace](https://kubernetes.io/docs/tasks/administer-cluster/namespaces/#deleting-a-namespace)

---

*End of Document*

```

---

If you want, I can help you commit this or customize it further!
```
