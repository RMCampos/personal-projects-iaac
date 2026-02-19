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

# check pvs status
kubectl get pvc -n bean-score -w
```

# Restart deployments

```
kubectl rollout restart deployment bean-score-db -n bean-score
kubectl rollout restart deployment bean-score-backend -n bean-score
kubectl rollout restart deployment syncable-backend -n syncable
```

# Get last events

```
kubectl get events -n bean-score --sort-by='.lastTimestamp'
```

# Delete pods

```
kubectl delete pod -l app=bean-score-db -n bean-score --force
```

# Import existing pvc, in case of errors

```
# terraform import <resource_type>.<resource_name> <namespace>/<k8s_name>

terraform import kubernetes_persistent_volume_claim_v1.bean_score_db_data bean-score/postgres-data-pvc
```

# Restore backup file

```
cat your_backup.sql | kubectl exec -i -n bean-score deployment/bean-score-db -- psql -U ${TF_VAR_db_user} -d ${TF_VAR_db_name}
```

# Check for cluster conditions

```
kubectl describe node | grep -A 10 Conditions
```
