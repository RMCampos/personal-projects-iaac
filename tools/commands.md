# List pods for a given namespace

```
kubectl get pods -n timez-people
```

# Get ingress

```
kubectl get ingress -n timez-people
```

# Get certificates

```
kubectl get certificate -n timez-people

# Challenges
kubectl get challenges -n timez-people

# Secrets
kubectl get secret timez-people-tls -n timez-people

# Describe
kubectl describe certificate timez-people-tls -n timez-people
```

# Get logs

```
kubectl logs -l app=bean-score-backend

# or
ubectl logs -l app=bean-score-backend --tail=100
```

# List things inside a volume or db

```
kubectl exec -it deployment/bean-score-db -n bean-score -- ls /docker-entrypoint-initdb.d/
```

# Restart deployments

```
kubectl rollout restart deployment bean-score-db -n bean-score
```
