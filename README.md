This project shows a minimal GitOps flow on **AWS EKS** using:
- **Terraform** to install **Argo CD** as a Helm release,
- a separate **app repo** with a **Helm chart for MLflow**,
- an **Argo CD Application** that auto-syncs from Git and deploys to the cluster.

**Author:** TetyanaCY  
**Cluster:** `ml-eks` (region `eu-central-1`)  
**Argo CD namespace:** `infra-tools`  
**App repo:** <https://github.com/TetyanaCY/mlflow-helm-app>  
**Helm chart path:** `helm/mlflow`  
**Application manifest:** `application.yaml` (repo root)

>  Cloud cost note: tear down resources when you’re done. Keep S3 state buckets if you use them for Terraform state.

---

## 1) Prerequisites

- AWS CLI, kubectl, Terraform ≥ 1.5, Git
- An existing EKS cluster and kubeconfig context you can use
- (Optional) S3 bucket if you plan to use remote Terraform state

Quick EKS connectivity check (PowerShell):
```powershell
aws sts get-caller-identity
aws eks update-kubeconfig --region eu-central-1 --name ml-eks
kubectl get nodes
2) Repo structure (expected)
Infra repo (Terraform for Argo CD) should look like:

pgsql
Always show details

Copy code
mlops-argocd-demo/
└─ argocd/
   ├─ main.tf
   ├─ variables.tf
   ├─ terraform.tf
   ├─ outputs.tf
   └─ values/
      └─ argocd-values.yaml
App repo (Helm chart + Argo CD Application):

markdown
Always show details

Copy code
mlflow-helm-app/
├─ application.yaml
└─ helm/
   └─ mlflow/
      ├─ Chart.yaml
      ├─ values.yaml
      └─ templates/
         ├─ deployment.yaml
         └─ service.yaml
3) Install Argo CD with Terraform
From the infra repo:

powershell
Always show details

Copy code
cd C:\Users\dell\projects\mlops-argocd-demo\argocd

terraform init
terraform apply -auto-approve `
  -var="aws_region=eu-central-1" `
  -var="cluster_name=ml-eks"
Verify pods & service:

powershell
Always show details

Copy code
kubectl get pods -n infra-tools
kubectl get svc  -n infra-tools
You should see pods like argocd-server, argocd-repo-server, argocd-application-controller; and a service argocd-server of type ClusterIP.

4) Open Argo CD UI (optional but recommended)
Port-forward (keep this terminal open):

powershell
Always show details

Copy code
kubectl -n infra-tools port-forward svc/argocd-server 8080:80
# then browse http://localhost:8080
Get initial admin password:

powershell
Always show details

Copy code
$raw = kubectl -n infra-tools get secret argocd-initial-admin-secret -o jsonpath='{.data.password}'
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($raw))
# username: admin
If you prefer not to use the UI, you can rely on CLI-only steps below.

5) Create/Apply the Argo CD Application
The Application manifest is stored in the app repo root (application.yaml) and points Argo CD at the MLflow Helm chart:

yaml
Always show details

Copy code
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mlflow
  namespace: infra-tools
spec:
  project: default
  source:
    repoURL: https://github.com/TetyanaCY/mlflow-helm-app.git
    targetRevision: HEAD
    path: helm/mlflow
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: mlflow
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
Apply it to the cluster (from the app repo folder):

powershell
Always show details

Copy code
cd C:\Users\dell\projects\mlflow-helm-app
kubectl apply -n infra-tools -f application.yaml

# force a fresh reconciliation if you want immediate sync
kubectl annotate application mlflow -n infra-tools argocd.argoproj.io/refresh=hard --overwrite
Check status:

powershell
Always show details

Copy code
kubectl get applications -n infra-tools
kubectl describe application mlflow -n infra-tools
6) Verify the deployment
powershell
Always show details

Copy code
kubectl get ns | findstr /I "^mlflow"
kubectl get deploy,svc,pods -n mlflow
kubectl rollout status deploy/mlflow-mlflow -n mlflow --timeout=180s
You should see:

Namespace mlflow

Deployment and Service mlflow (port 5000)

Pod in Running/Ready state

7) Access the MLflow UI
powershell
Always show details

Copy code
kubectl -n mlflow port-forward svc/mlflow 5000:5000
# then browse http://localhost:5000
If you prefer CLI-only verification (no browser), confirm a 200 OK from inside the cluster:

powershell
Always show details

Copy code
kubectl -n mlflow run curl --rm -it --image=curlimages/curl:8.10.1 --restart=Never -- `
  curl -sSI http://mlflow:5000/
8) Troubleshooting
Argo CD UI says “Failed to load data”

Keep port-forward running; hard refresh; or clear site data and re-login.

MLflow pod CrashLoopBackOff / OOMKilled

Use a lighter process and fewer workers, increase memory:

In Deployment args use mlflow ui (instead of server).

Add env:

yaml
Always show details

Copy code
- name: GUNICORN_CMD_ARGS
  value: "--workers 1 --timeout 120"
In values.yaml:

yaml
Always show details

Copy code
resources:
  requests:
    memory: "512Mi"
  limits:
    memory: "1Gi"
image:
  tag: v2.14.1
Commit & push changes; then force Argo CD to resync:

powershell
Always show details

Copy code
kubectl annotate application mlflow -n infra-tools argocd.argoproj.io/refresh=hard --overwrite
Private Git repo

Add your repo in Argo CD UI → Settings → Repositories → Connect (HTTPS with username + PAT, or SSH).

9) Clean up (avoid unintended costs)
powershell
Always show details

Copy code
# optional: remove the Application
kubectl delete -n infra-tools -f C:\Users\dell\projects\mlflow-helm-app\application.yaml

# remove Argo CD via Terraform
cd C:\Users\dell\projects\mlops-argocd-demo\argocd
terraform destroy -auto-approve `
  -var="aws_region=eu-central-1" `
  -var="cluster_name=ml-eks"
10) Links
App repo (Helm + Application): https://github.com/TetyanaCY/mlflow-helm-app
Helm chart: https://github.com/TetyanaCY/mlflow-helm-app/tree/main/helm/mlflow

(Optional) Infra repo (Terraform/Argo CD, branch lesson-7): https://github.com/TetyanaCY/mlops-argocd-demo/tree/lesson-7/argocd

Argo CD docs: https://argo-cd.readthedocs.io/

MLflow: https://mlflow.org/
"""

with open("/mnt/data/README.md", "w", encoding="utf-8") as f:
f.write(readme)

"/mnt/data/README.md"
