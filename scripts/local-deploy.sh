#!/bin/bash
set -e

echo "======================================"



echo "======================================"
echo "📦 Building FRONTEND"
echo "======================================"
cd /home/vagrant/project/frontend
DOCKER_USERNAME=tumbaoka
docker build -t $DOCKER_USERNAME/sherlock-logs-frontend:latest .
docker tag $DOCKER_USERNAME/sherlock-logs-frontend:latest $DOCKER_USERNAME/sherlock-logs-frontend:prod
echo "🚀 Pushing FRONTEND images..."
docker push $DOCKER_USERNAME/sherlock-logs-frontend:latest
docker push $DOCKER_USERNAME/sherlock-logs-frontend:prod

echo "======================================"
echo "📦 Building BACKEND"
echo "======================================"
cd /home/vagrant/project/backend
docker build -t $DOCKER_USERNAME/sherlock-logs-backend:latest .
docker tag $DOCKER_USERNAME/sherlock-logs-backend:latest $DOCKER_USERNAME/sherlock-logs-backend:prod
echo "🚀 Pushing BACKEND images..."
docker push $DOCKER_USERNAME/sherlock-logs-backend:latest
docker push $DOCKER_USERNAME/sherlock-logs-backend:prod

echo "======================================"
echo "☸️ DEPLOYING TO KUBERNETES"
echo "======================================"
cd ~/project
kubectl apply -f manifests/kubernetes/
echo "🔄 Restarting deployments..."
kubectl rollout restart deployment/frontend || true
kubectl rollout restart deployment/backend || true
kubectl rollout status deployment/frontend --timeout=180s || true
kubectl rollout status deployment/backend --timeout=180s || true
echo "======================================"
echo "📊 CLUSTER STATUS"
echo "======================================"
kubectl get pods
kubectl get svc
kubectl get all
echo "======================================"
echo "✅ PIPELINE COMPLETED SUCCESSFULLY"
echo "======================================"

sleep 15
kubectl get pods
