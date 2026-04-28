#!/bin/bash
set -e

echo "🚀 CI/CD STARTED"

# Load env
set -a
source .env
set +a

# Login to Docker
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

TAG=$(git rev-parse --short HEAD)

#######################################
# FRONTEND
#######################################
echo "📦 Building Frontend"
cd ~/project/frontend

docker build -t $DOCKER_USERNAME/frontend:$TAG .
docker push $DOCKER_USERNAME/frontend:$TAG

#######################################
# BACKEND
#######################################
echo "📦 Building Backend"
cd ~/project/backend

docker build -t $DOCKER_USERNAME/backend:$TAG .
docker push $DOCKER_USERNAME/backend:$TAG

#######################################
# UPDATE KUBERNETES ONLY
#######################################
echo "☸️ Updating Kubernetes"

kubectl set image deployment/frontend frontend=$DOCKER_USERNAME/frontend:$TAG
kubectl set image deployment/backend backend=$DOCKER_USERNAME/backend:$TAG

kubectl rollout status deployment/frontend
kubectl rollout status deployment/backend

echo "✅ DONE"