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
