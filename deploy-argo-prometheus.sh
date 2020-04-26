#!/bin/bash
set -ex

# download kind
if [ ! -f ~/kind ]; then
  curl https://github.com/kubernetes-sigs/kind/releases/download/v0.7.0/kind-linux-amd64 \
    --location \
    --output ~/kind

  chmod +x ~/kind
fi

~/kind version


# create cluster
if ! ~/kind get clusters | grep kind ; then
  ~/kind create cluster
fi


# download kubectl
if [ ! -f ~/kubectl ]; then
  curl https://storage.googleapis.com/kubernetes-release/release/v1.17.0/bin/linux/amd64/kubectl \
    --location \
    --output ~/kubectl

  chmod +x ~/kubectl
fi

~/kubectl version


# deploy argo
if ! ~/kubectl get namespace argo ; then
  ~/kubectl create namespace argo
fi

~/kubectl apply \
  --filename https://raw.githubusercontent.com/argoproj/argo/v2.7.2/manifests/namespace-install.yaml \
  --namespace argo

~/kubectl wait deployment workflow-controller \
  --for condition=Available \
  --namespace argo \
  --timeout=300s

if ! ~/kubectl get rolebinding default-admin --namespace argo ; then
  ~/kubectl create rolebinding default-admin \
    --clusterrole cluster-admin \
    --namespace argo \
    --serviceaccount=argo:default
fi


# configure argo to work in kind
~/kubectl patch configmap workflow-controller-configmap \
  --namespace argo \
  --patch '{"data": {"containerRuntimeExecutor": "pns"}}' \
  --type merge


# patch argo to work with prometheus
~/kubectl patch configmap workflow-controller-configmap \
  --namespace argo \
  --patch '{"data": {"metricsConfig": "enabled: true\npath: /metrics\nport: 9090"}}' \
  --type merge

~/kubectl delete pods \
  --namespace argo \
  --selector app=workflow-controller

~/kubectl patch service workflow-controller-metrics \
  --namespace argo \
  --patch '[{"op": "add", "path": "/spec/ports/0/name", "value": "metrics"}]' \
  --type json


# download argo CLI
if [ ! -f ~/argo ]; then
  curl https://github.com/argoproj/argo/releases/download/v2.7.2/argo-linux-amd64 \
    --location \
    --output ~/argo

  chmod +x ~/argo
fi

~/argo version


# run hello-world argo workflow
~/argo submit https://raw.githubusercontent.com/argoproj/argo/v2.7.2/examples/hello-world.yaml \
  --namespace=argo \
  --watch


# deploy prometheus
if [ ! -d ~/kube-prometheus ]; then
  git clone https://github.com/coreos/kube-prometheus.git ~/kube-prometheus
fi

cd ~/kube-prometheus

git checkout v0.3.0

~/kubectl apply --filename ~/kube-prometheus/manifests/setup/
until ~/kubectl get servicemonitors --all-namespaces ; do sleep 1; done
~/kubectl apply --filename ~/kube-prometheus/manifests/


# configure prometheus RBAC
if ! ~/kubectl get role prometheus-k8s --namespace argo ; then
  ~/kubectl create role prometheus-k8s \
    --namespace argo \
    --resource services,endpoints,pods \
    --verb get,list,watch
fi

if ! ~/kubectl get rolebinding prometheus-k8s --namespace argo ; then
  ~/kubectl create rolebinding prometheus-k8s \
    --namespace argo \
    --role prometheus-k8s \
    --serviceaccount monitoring:prometheus-k8s
fi


# create workflow-controller-metrics servicemonitor
cat <<EOF > ~/workflow-controller-metrics-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: workflow-controller-metrics
  namespace: argo
spec:
  endpoints:
    - port: metrics
  namespaceSelector:
    matchNames:
      - argo
  selector:
    matchNames:
      - workflow-controller-metrics
EOF

~/kubectl apply \
  --filename ~/workflow-controller-metrics-servicemonitor.yaml
