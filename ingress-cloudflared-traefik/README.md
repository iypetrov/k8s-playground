Configuration for Traefik
```bash
helm install traefik traefik/traefik --namespace traefik --create-namespace -f charts/traefik/values.yml
```

If you want to update the configuration of Traefik, you can use the following command:
```bash 
helm upgrade traefik traefik/traefik --namespace traefik -f charts/traefik/values.yml
```
