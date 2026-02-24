# personal-projects-iaac

A single repository that gathers all Infrastructure as Code (IaaC) definitions for personal projects. Each subdirectory contains the infrastructure configuration for a specific project, primarily deployed to a self-hosted Kubernetes cluster using [Terraform](https://www.terraform.io/) and [k3s](https://k3s.io/).

## Terraform

[Terraform](https://www.terraform.io/) is an open-source Infrastructure as Code tool by HashiCorp that lets you define and provision infrastructure using a declarative configuration language (HCL).

### Installing Terraform

**Linux (Debian/Ubuntu):**
```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**macOS (Homebrew):**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Verify installation:**
```bash
terraform --version
```

### Basic Usage

Navigate into any project directory and run:

```bash
# Initialize Terraform (download providers)
terraform init

# Preview changes
terraform plan -var="db_user=myuser" -var="db_password=mypassword" -var="db_name=mydb"

# Apply changes
terraform apply -var="db_user=myuser" -var="db_password=mypassword" -var="db_name=mydb"

# Using environment variables (recommended)
export TF_VAR_db_user="myuser"
export TF_VAR_db_password="mypassword"
export TF_VAR_db_name="mydb"
terraform apply
```

## Projects

### [`bean-score`](./bean-score)

Infrastructure for the **Bean Score** application — a coffee shop scoring app with a React frontend, a Quarkus (Java) backend, and a PostgreSQL database. Deploys to the `bean-score` Kubernetes namespace and exposes the app via HTTPS using Traefik and cert-manager.

### [`cluster-issuer`](./cluster-issuer)

A Kubernetes `ClusterIssuer` manifest (`issuer.yaml`) that configures [cert-manager](https://cert-manager.io/) to issue TLS certificates from Let's Encrypt using the ACME HTTP-01 challenge with Traefik. This must be applied before deploying any project that requires HTTPS.

```bash
kubectl apply -f cluster-issuer/issuer.yaml
```

### [`dozzle`](./dozzle)

Infrastructure for **[Dozzle](https://dozzle.dev/)** — a real-time log viewer for Kubernetes pods. Deploys Dozzle in Kubernetes mode with the necessary RBAC (ServiceAccount, ClusterRole, ClusterRoleBinding) so it can read logs from all namespaces.

### [`espresso-url`](./espresso-url)

Infrastructure for the **Espresso URL** application — a URL shortener with a Node.js/Prisma backend and a Vite frontend, backed by a PostgreSQL database. Uses an init container to run Prisma migrations on startup.

### [`server`](./server)

Setup commands and documentation ([`commands.md`](./server/commands.md)) for bootstrapping a bare-metal or VPS server with:
- k3s (lightweight Kubernetes)
- kubectx & kubens
- cert-manager

### [`syncable`](./syncable)

Infrastructure for the **Syncable** application — a Node.js backend service with a PostgreSQL database. Includes liveness and readiness probes and deploys behind a TLS-terminated ingress.

### [`tasknote`](./tasknote)

Infrastructure for the **Tasknote** application — a task/note management app with a Spring Boot backend (with Mailgun email integration), a Vite frontend, and a PostgreSQL database.

### [`timez-people`](./timez-people)

Infrastructure for the **Timez People** application — a simple frontend-only app for displaying people's local times. Deploys a single container behind a TLS-terminated Traefik ingress.

### [`tools`](./tools)

Utility scripts and commands for cluster operations:
- [`commands.md`](./tools/commands.md) — common `kubectl` and `terraform` commands for managing deployments, logs, certificates, and PVCs.
- `do-backup.sh` — creates a PostgreSQL backup from a running pod.
- `do-backup-restore.sh` — restores a PostgreSQL backup into a running pod.
- `do-backup-try-restore.sh` — runs a test restore to verify backup integrity.

