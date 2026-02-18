# Install k8s

```
# Disable swap
# To keep swap off after reboot, edit /etc/fstab and comment out the swap line.
sudo swapoff -a

curl -sfL https://get.k3s.io | sh -

# Copy file
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Update IP to external
# Change from 127.0.0.1 to real IP

# Check if the node is ready
sudo k3s kubectl get nodes
```

# Get current external IP

```
curl ifconfig.me
```

# Install kubectx & kubens

```
# Download kubectx
sudo wget https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx -O /usr/local/bin/kubectx

# Download kubens
sudo wget https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens -O /usr/local/bin/kubens

# Make them executable
sudo chmod +x /usr/local/bin/kubectx /usr/local/bin/kubens
```

# HTTPS and Certmanager

```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
```

# Apply tf with secrets

```
# Simple way - beginner
terraform apply -var="db_user=here" -var="db_password=here" -var="db_name=here"

# Better way - senior? LOL
export TF_VAR_db_password="my-super-secret-password"
teraform apply
```
