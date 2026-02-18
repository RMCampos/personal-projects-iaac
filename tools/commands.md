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
kubectl logs -l app=bean-score-backend --tail=100

# from DB
kubectl logs -l app=bean-score-db -n bean-score
```

# List things inside a volume or db

```
kubectl exec -it deployment/bean-score-db -n bean-score -- ls /docker-entrypoint-initdb.d/

# check pvc attached
kubectl describe pod -l app=bean-score-db -n bean-score
```

# Restart deployments

```
kubectl rollout restart deployment bean-score-db -n bean-score
kubectl rollout restart deployment bean-score-backend -n bean-score
```

# Get last events

```
kubectl get events -n bean-score --sort-by='.lastTimestamp'
```

# Delete pods

```
kubectl delete pod -l app=bean-score-db -n bean-score --force
```
