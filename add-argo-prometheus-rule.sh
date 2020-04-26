#!/bin/bash
set -ex

# patch k8s Prometheus to use PrometheusRules in all namespaces
~/kubectl patch prometheus k8s \
  --namespace monitoring \
  --patch '{"spec": {"ruleNamespaceSelector": {}}}' \
  --type merge


# create a PrometheusRule for workflow-controller-metrics service
cat <<EOF > ~/workflow-controller-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: workflow-controller-rules
  namespace: argo
  labels:
    prometheus: k8s
    role: alert-rules
spec:
  groups:
    - name: argo-workflows
      rules:
        - expr: argo_workflow_status_phase{phase = "Failed"} == 1
          alert: WorkflowFailures
EOF

~/kubectl apply \
  --filename ~/workflow-controller-rules.yaml


# create a failing Argo Workflow so alert is fired
cat <<EOF > ~/workflow-fail.yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: fail-
spec:
  entrypoint: fail
  templates:
  - name: fail
    container:
      image: busybox:latest
      command: [false]
EOF

~/argo submit ~/workflow-fail.yaml \
  --namespace=argo \
  --watch
