cd ~/projects
cd frontend
docker build -t 192.168.56.15:5000/sherlock-logs-frontend:prod .
docker tag 192.168.56.15:5000/sherlock-logs-frontend:prod 192.168.56.15:5000/sherlock-logs-frontend:latest

cd ../backend
docker build -t 192.168.56.15:5000/sherlock-logs-backend:prod .
docker tag 192.168.56.15:5000/sherlock-logs-backend:prod 192.168.56.15:5000/sherlock-logs-backend:latest

cd ..
docker push 192.168.56.15:5000/sherlock-logs-frontend:prod
docker push 192.168.56.15:5000/sherlock-logs-frontend:latest
docker push 192.168.56.15:5000/sherlock-logs-backend:prod
docker push 192.168.56.15:5000/sherlock-logs-backend:latest


kubectl apply -f manifests/kubernates/
kubectl rollout restart deployment/sherlock-logs-frontend
kubectl rollout restart deployment/sherlock-logs-backend

kubectl get svc
kubectl get pods
kubectl get all