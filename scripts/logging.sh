kubectl create namespace logging
kubectl apply -f manifests/logging/ 
kubectl get svc -n logging

kubectl get nodes -o wide