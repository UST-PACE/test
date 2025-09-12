# Cleanup Guide: Stuck Kubernetes Namespace After Helm Uninstall

This guide documents the step-by-step process to resolve a Kubernetes namespace stuck in the `Terminating` state after uninstalling a monitoring stack (Grafana/K8s monitoring) deployed via Helm.

---

## Background

After uninstalling Helm charts related to Grafana and Kubernetes monitoring from the `prometheus` namespace, the namespace remained stuck in the `Terminating` state for an extended period. Pods and custom resources (`alloys.collectors.grafana.com`) were stuck terminating due to remaining finalizers preventing full cleanup.

---

## Problem

- Namespace `prometheus` stuck in `Terminating`
- Pods stuck terminating for 28+ days
- Custom resources (CRs) of kind `alloy.collectors.grafana.com` persisted with finalizers
- Finalizers included `helm.sdk.operatorframework.io/uninstall-release`
- Namespace finalizers also blocked deletion

---

## Objective

- Remove Helm-related finalizers from custom resources blocking deletion
- Remove finalizers from the namespace
- Fully delete all resources and the namespace cleanly

---

## Step-by-Step Resolution

### 1. Verify stuck pods and resources in the namespace

```bash
kubectl get pods -n prometheus
kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get -n prometheus --ignore-not-found
