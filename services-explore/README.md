```bash
# To apply changes use:
kubectl apply -f .

# To access the service go to `http://localhost:30080` (service type is NodePort) 

# To access the service via port forwarding:
kubectl port-forward svc/nginx-service 8080:8080
```
