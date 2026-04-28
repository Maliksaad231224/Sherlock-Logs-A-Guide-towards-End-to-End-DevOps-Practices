#!/bin/bash

set -e

echo "📦 Installing Helm..."

if ! command -v helm &> /dev/null; then
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
echo "Helm already installed"
fi


echo "📦 Adding Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

echo "📁 Creating namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

echo "🚀 Installing / Upgrading kube-prometheus-stack..."
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  --timeout 15m

echo "✅ Done"
kubectl get pods -n monitoring

kubectl get secret -n monitoring monitoring-grafana \
-o jsonpath="{.data.admin-password}" | base64 -d ; echo

kubectl patch svc monitoring-grafana -n monitoring \
-p '{"spec": {"type": "NodePort"}}'

kubectl get svc -n monitoring monitoring-grafana

echo "grafana url :http://192.168.56.10:30632"
echo "grafana username :admin"
echo "grafana password :$(kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo)"

kubectl patch svc monitoring-kube-prometheus-prometheus -n monitoring \
-p '{"spec": {"type": "NodePort"}}'

kubectl get svc -n monitoring | grep prometheus

echo "prometheus is http://192.168.56.10:32252"