# DevOps Lab: Terraform, Kubernetes, Helm and GitOps (ArgoCD) with CI

A small hands-on lab to practice Infrastructure as Code, Kubernetes, Helm, GitOps and CI.
It is a learning project, not a production setup.

## What is inside

| Part | What it does |
|------|--------------|
| `terraform/` | Creates an Azure resource group and a storage account with Terraform |
| `k8s/` | Plain Kubernetes manifests: Deployment (2 replicas, probes, resource limits) and a NodePort Service |
| `helm/nekouv/` | The same app as a Helm chart, configurable through `values.yaml` |
| `argocd/application.yaml` | ArgoCD Application that deploys the Helm chart from this Git repository (GitOps) |
| `.github/workflows/ci.yml` | On every push: `terraform fmt -check` and `validate`, manifest validation with kubeconform, `helm lint`, and validation of the rendered chart |

## Prerequisites

- Azure account (a free student account is enough) and the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Docker](https://docs.docker.com/get-docker/), [minikube](https://minikube.sigs.k8s.io/docs/start/), `kubectl`
- [Helm](https://helm.sh/docs/intro/install/) 3

## Part 1: Terraform on Azure

```bash
az login
az account show --query id -o tsv        # copy your subscription id

cd terraform
cp terraform.tfvars.example terraform.tfvars   # optional; or pass -var instead
terraform init
terraform plan -var "subscription_id=<YOUR_ID>"
terraform apply -var "subscription_id=<YOUR_ID>"
```

Check the result in the Azure portal or with `az group show -n rg-nekouv-lab`.

**Always clean up when you finish, so nothing keeps running or costing money:**

```bash
terraform destroy -var "subscription_id=<YOUR_ID>"
```

If you get a region/policy error on a student account, pass another region:
`-var "location=northeurope"`.

## Part 2: Kubernetes on minikube (plain manifests)

```bash
minikube start --driver=docker
kubectl apply -f k8s/
kubectl get pods
kubectl rollout status deployment/nekouv
minikube service nekouv --url             # open the printed URL in a browser
```

Things to try (this is where the learning happens):

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl scale deployment nekouv --replicas=4
kubectl delete pod <pod-name>             # watch the Deployment recreate it
kubectl set image deployment/nekouv nekouv=nginx:1.26-alpine   # rolling update
kubectl rollout undo deployment/nekouv
```

Clean up before the next parts: `kubectl delete -f k8s/` (the Helm chart uses the same names).

To run your own app, build the image (`docker build`), make it available to minikube
(`minikube image load <image>`), then change `image:`, `containerPort` and the probe
paths in `k8s/deployment.yaml` (or in `helm/nekouv/values.yaml`).

## Part 3: Helm

```bash
helm lint helm/nekouv
helm template nekouv helm/nekouv          # see the rendered manifests, nothing is applied
helm install nekouv helm/nekouv
helm list
kubectl get pods

helm upgrade nekouv helm/nekouv --set replicaCount=3     # new revision
helm history nekouv
helm rollback nekouv 1
helm uninstall nekouv
```

## Part 4: GitOps with ArgoCD

1. Push this repository to GitHub (public, so the cluster can read it without credentials).
2. Make sure nothing from Parts 2 and 3 is still installed (`kubectl delete -f k8s/` / `helm uninstall nekouv`).
3. Install ArgoCD in minikube:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd get pods                 # wait until everything is Running

# initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# open the UI at https://localhost:8080 (user: admin)
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

4. Edit `argocd/application.yaml`: put your own repository URL in `repoURL`. Then:

```bash
kubectl apply -f argocd/application.yaml
kubectl -n nekouv get pods
```

5. Try the GitOps loop:
   - Change `replicaCount` in `helm/nekouv/values.yaml`, commit and push. ArgoCD syncs the change (it polls Git every few minutes; press Refresh in the UI to speed it up).
   - Scale manually with `kubectl -n nekouv scale deployment nekouv --replicas=5` and watch `selfHeal` revert it to what Git says.
   - Remove the Service template, push, and see `prune` delete it from the cluster.

Clean up: `kubectl delete -f argocd/application.yaml`, then `minikube stop` or `minikube delete`.

## Part 5: CI

The workflow in `.github/workflows/ci.yml` needs no cloud credentials. It checks that the Terraform code is
formatted and valid, that the plain manifests match the Kubernetes schema, and that the Helm chart lints
and renders into valid manifests. Push to GitHub and look at the Actions tab.

## Concepts to be able to explain

- What `terraform init`, `plan`, `apply` and `destroy` do, and what the state file is for
- Why `terraform.tfstate` and `*.tfvars` are in `.gitignore`
- Pod vs Deployment vs Service; what readiness and liveness probes do
- Why resource requests and limits matter
- What a rolling update is and how to roll back (`kubectl rollout undo`, `helm rollback`)
- What a Helm chart, a release, `values.yaml` and a template are; the difference between `helm template` and `helm install`
- What GitOps means: Git is the single source of truth and the cluster is reconciled to it
- What ArgoCD does, and what `automated`, `prune` and `selfHeal` mean in the sync policy
- What each job in the CI workflow checks and why
