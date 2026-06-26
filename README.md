![CE12 Group 5](docs/images/ce12_grp5.jpeg)
# SCTP CE12 Group 5 Capstone Project

Sandbox repository for the CE12 DevOps Capstone project — a hands-on exploration of how modern teams provision infrastructure, deploy applications, and keep them running in practice.

## The Team

- SK (Team Lead)
- Arista
- Gina
- Indy
- ƒαιzαℓ.

---

## What We Built

This is a **learning project** that explores how modern DevOps teams operate in practice. We deployed a sample retail store application onto AWS and built the surrounding platform — the infrastructure, automation, and observability tooling — from scratch.

The application itself (a fictional online store with five services: catalogue, cart, checkout, orders, and UI) is a stand-in. The real focus was on the platform around it: how to provision infrastructure reliably, deploy changes safely, know when something breaks, and understand what it costs to run.

We used the same categories of tools that engineering teams at real companies use. This is not a production system — it has no TLS, no CI pipeline, no multi-environment setup, and the app images are pre-built rather than owned by us. But it gave us hands-on experience with each layer of a real deployment pipeline.

### What Each Tool Does

| What it does | Tool used |
|---|---|
| Provision cloud servers and networking | Terraform |
| Run and manage containerised services | Amazon EKS (Kubernetes) |
| Deploy changes automatically from Git | ArgoCD |
| Monitor system health and performance | Prometheus + Grafana |
| Collect and search application logs | Fluent Bit + Loki |
| Send alerts when something breaks | Alertmanager → Discord |
| Track cloud spending | Kubecost |
| Automatically manage DNS records | ExternalDNS |
| Simulate server failures to test resilience | AWS Fault Injection Service |

### How a Change Gets Deployed

```
Developer pushes code to GitHub
        ↓
ArgoCD detects the change (within ~3 minutes)
        ↓
ArgoCD applies it to the cluster automatically
        ↓
Prometheus checks that everything is still healthy
        ↓
If something breaks → Alertmanager sends a Discord alert
```

### What This Project Is Not

- **Not a production system** — there is no HTTPS, no secrets manager, and no hardened security posture
- **Not a CI/CD pipeline** — there is no automated image building or testing; the app images are pre-built from the [AWS EKS Workshop](https://www.eksworkshop.com/) reference app and we deploy them as-is
- **Not multi-environment** — there is one cluster and one environment; a real setup would have separate dev, staging, and production
- **Not auto-scaling** — pod and node scaling are not configured
- **Not owned application code** — we do not control what is inside the container images; this project is about the platform, not the application

---

## Live URLs

| Service | URL |
|---|---|
| Retail Store | http://grp5.sctp-sandbox.com |
| Grafana (dashboards) | http://grp5-grafana.sctp-sandbox.com |
| ArgoCD (deployments) | http://grp5-argocd.sctp-sandbox.com |
| Kubecost (cloud spend) | http://grp5-kubecost.sctp-sandbox.com |

---

## What Happens When Something Breaks

We set up two alerts to fire during the node failure demo. Here is what each one means and what happens when it triggers.

### NodeNotReady (severity: critical)

**What triggers it:** A cluster node (virtual server) has not reported itself as healthy for more than 15 seconds — usually because it was terminated or crashed.

**What you see:**
- The Grafana dashboard panel turns red with "FIRING!"
- Alertmanager sends a message to the team Discord channel

**What happens next:** Because we use an EKS managed node group, AWS automatically detects the failed node and launches a replacement. The cluster reschedules the affected pods onto healthy nodes. Within a few minutes everything is green again — no manual action needed.

### RetailStorePodsPending (severity: warning)

**What triggers it:** One or more application pods have been stuck waiting to start for more than 5 seconds. This is the expected knock-on effect of a node failure — Kubernetes evicts pods from the dead node and has to find somewhere else to run them.

**What you see:**
- The Grafana dashboard panel turns red with "FIRING!"
- A second Discord message arrives indicating which namespace is affected

**What happens next:** Once the replacement node is ready and joins the cluster, the pending pods are scheduled onto it and start running. This alert typically resolves itself a minute or two after NodeNotReady clears.

Both alerts are defined in [`manifests/alerts/prometheusrule.yaml`](manifests/alerts/prometheusrule.yaml). You can trigger them deliberately using the [node failure demo](#demo-node-failure-simulation) below.

---

## Design Decisions

Each major tool choice in this project is documented as an Architecture Decision Record (ADR) in [`docs/adr/`](docs/adr/). These explain what we chose, what we considered, and why.

| ADR | Decision |
|---|---|
| [0001](docs/adr/0001-compute-platform.md) | Why Amazon EKS for compute |
| [0002](docs/adr/0002-gateway-api-vs-ingress.md) | Gateway API instead of classic Ingress |
| [0003](docs/adr/0003-helmfile-kustomize-split.md) | Splitting Helmfile (platform) and Kustomize (app) |
| [0004](docs/adr/0004-observability-stack.md) | Prometheus, Grafana, Loki, and OpenTelemetry for observability |
| [0005](docs/adr/0005-dedicated-observability-node-group.md) | Dedicated tainted node group for observability workloads |
| [0006](docs/adr/0006-terraform-remote-state-s3.md) | S3 remote state with native locking for Terraform |
| [0007](docs/adr/0007-kubecost-for-cost-visibility.md) | Kubecost for cost visibility |
| [0008](docs/adr/0008-aws-fis-for-chaos-engineering.md) | AWS FIS for chaos and failure-injection testing |

---

## Known Limitations

These are things we are aware of but did not implement, either because they were out of scope for a learning project or because they would require significantly more time and infrastructure.

- **No HTTPS** — all services are plain HTTP; a real system would use TLS with ACM or cert-manager
- **No CI pipeline** — there is no automated image building, unit testing, or vulnerability scanning; we deploy pre-built images from the AWS EKS Workshop
- **No secrets manager** — sensitive values like the Discord webhook URL are stored as plain Kubernetes Secrets, not in AWS Secrets Manager or Vault
- **No multi-environment** — one cluster, one environment; a real setup would separate dev, staging, and production with promotion gates between them
- **No auto-scaling** — Horizontal Pod Autoscaler and Cluster Autoscaler are not configured
- **No RBAC** — all team members have cluster-admin access; a real system would scope permissions by role
- **No network policies** — services can communicate freely within the cluster with no restrictions
- **Single region** — no cross-region redundancy or disaster recovery

---

## Architecture Overview

This repo deploys a sample retail-store application (five microservices: `carts`, `catalog`, `checkout`,
`orders`, `ui`) onto Amazon EKS, along with a full observability stack (Prometheus, Grafana, Loki,
OpenTelemetry, Kubecost) and supporting AWS infra (VPC, IAM roles, load balancer, DNS).

Deployment happens in three layers, always in this order:

1. **Terraform** (`terraform/`) — creates the VPC, EKS cluster, node groups, and IAM roles.
2. **Helmfile** (`helm/`) — installs cluster controllers and platform services (load balancer controller,
   external-dns, Prometheus stack, Loki, OpenTelemetry operator, Kubecost).
3. **Kustomize** (`manifests/`) — deploys the application microservices and alerting rules.

After the first apply, [ArgoCD](#argocd-repo-credential-set-up-before-the-kustomize-apply-below) takes over syncing the app layer
(`manifests/`) automatically on every commit to `main` — Terraform and Helmfile still need to be run
manually as above.

For details on what each Helm release/CRD is responsible for, see
[`docs/installation.md`](docs/installation.md). For the metrics each service exposes and example Grafana
queries, see [`docs/app_metrics.md`](docs/app_metrics.md).

---

## Prerequisites

Install and configure these tools before starting:

| Tool | Purpose | Used version |
|---|---|---|
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | AWS access, run `aws configure` first | any recent v2 |
| [Terraform](https://developer.hashicorp.com/terraform/install) | Provision VPC/EKS/IAM | v1.15+ |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Talk to the cluster | v1.36+ |
| [Helmfile](https://github.com/helmfile/helmfile#installation) | Install Helm charts declaratively | v1.5+ |
| [Helm](https://helm.sh/docs/intro/install/) | Used internally by Helmfile | any recent v3 |
| `envsubst` (part of `gettext`) | Substitute env vars into templated YAML | any |
| `jq` | Parse JSON output in the DEMO section | any |

You also need AWS credentials with permission to create the resources above, and to be listed in
`cluster_admins` in [`terraform/variables.tf`](terraform/variables.tf) if you want `kubectl` admin access
to the cluster.

## Project Structure

```text
ce12-capstone-sandbox/
├── docs/
│   ├── adr/                    # Architecture Decision Records — why each tool was chosen
│   ├── images/
│   ├── app_metrics.md          # Per-service metrics reference and example Grafana queries
│   ├── architecture.drawio     # Architecture diagram source file
│   └── installation.md        # CRD ownership and Helmfile/Kustomize split details
├── helm/
│   ├── crds/
│   ├── values/
│   ├── helmfile.yaml.gotmpl
│   └── retained-storage.yaml
├── manifests/
│   ├── adot/
│   ├── alerts/
│   ├── argocd/
│   ├── carts/
│   ├── catalog/
│   ├── checkout/
│   ├── fluentbit/
│   ├── grafana/
│   ├── kubecost/
│   ├── load-gen/
│   ├── orders/
│   ├── otel-instrumentation/
│   ├── ui/
│   └── kustomization.yaml
├── terraform/
│   ├── eks.tf
│   ├── iam.tf
│   ├── main.tf
│   ├── providers.tf
│   ├── variables.tf
│   └── vpc.tf
├── .gitignore
└── README.md
```

---

## Setup

These steps only need to be run once per environment, before the first `terraform apply`.

### 1. Create the S3 buckets

Terraform's state and Loki's log chunks both live in S3 and must exist _before_ you run Terraform.

```bash
# Bucket for Terraform remote state (matches terraform/providers.tf backend config)
aws s3api create-bucket \
  --bucket capstone-project-group5 \
  --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1

# Bucket for Loki chunk/index storage (matches terraform/variables.tf loki_bucket_name
# and helm/values/loki.yaml bucketNames)
aws s3api create-bucket \
  --bucket retail-store-grp5-loki-chunks \
  --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1
```

### 2. Create the retained EBS volumes

Grafana, Prometheus, Loki, Alertmanager, and Kubecost each get a "retained" EBS volume so their data
survives a `helmfile destroy`/`sync` cycle (see [`helm/retained-storage.yaml`](helm/retained-storage.yaml)).
Create one volume per service, all in the same AZ used by the `observability` node group
(`ap-southeast-1c`, see [`terraform/eks.tf`](terraform/eks.tf)):

```bash
aws ec2 create-volume --region ap-southeast-1 --availability-zone ap-southeast-1c --size 20 --volume-type gp3 --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=retail-store-grp5-prometheus-retained}]'
aws ec2 create-volume --region ap-southeast-1 --availability-zone ap-southeast-1c --size 20 --volume-type gp3 --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=retail-store-grp5-loki-retained}]'
aws ec2 create-volume --region ap-southeast-1 --availability-zone ap-southeast-1c --size 10 --volume-type gp3 --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=retail-store-grp5-grafana-retained}]'
aws ec2 create-volume --region ap-southeast-1 --availability-zone ap-southeast-1c --size 10 --volume-type gp3 --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=retail-store-grp5-alertmanager-retained}]'
aws ec2 create-volume --region ap-southeast-1 --availability-zone ap-southeast-1c --size 20 --volume-type gp3 --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=retail-store-grp5-kubecost-retained}]'
```

These volumes are created once and then reused on every future `helmfile sync` — you don't need to
recreate them unless they're deleted. Their IDs are looked up by tag in the "Helm Chart installation"
step below, so you don't need to copy/paste volume IDs by hand.

---

## Startup

### Provision VPC, EKS Cluster

```bash
terraform -chdir=terraform init
terraform -chdir=terraform apply
```

### Helm Chart Installation

First point `kubectl`/`helm` at the new cluster and export the account/VPC IDs the chart values need:

```bash
aws eks --region ap-southeast-1 update-kubeconfig --name retail-store-grp5
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export VPC_ID=$(aws eks describe-cluster --name retail-store-grp5 --region ap-southeast-1 --query 'cluster.resourcesVpcConfig.vpcId' --output text)
```

Next, set the volume IDs for these EBS volumes. **Use the fixed volume IDs below rather than looking
them up by `Name` tag.** The `Name` tag is not unique in EC2 — if a volume ever gets recreated (e.g.
re-running the `create-volume` commands in [Setup](#setup)), the new volume keeps the same `Name` tag as
the original, so a tag-based lookup (`describe-volumes --filters Name=tag:Name,...`) can silently match
the wrong (duplicate) volume and pick up empty data instead of the original retained data. Pinning the
known volume ID avoids that ambiguity entirely:

```bash
export PROMETHEUS_EBS_VOLUME_ID=vol-0fd603b3e2cf7ca08
export PROMETHEUS_EBS_AZ=ap-southeast-1c
export LOKI_EBS_VOLUME_ID=vol-03735bc2949c6340d
export LOKI_EBS_AZ=ap-southeast-1c
export GRAFANA_EBS_VOLUME_ID=vol-051c46eca0f1598f7
export GRAFANA_EBS_AZ=ap-southeast-1c
export ALERTMANAGER_EBS_VOLUME_ID=vol-0604f19be368a27a1
export ALERTMANAGER_EBS_AZ=ap-southeast-1c
export KUBECOST_EBS_VOLUME_ID=vol-0a8125c27398ef004
export KUBECOST_EBS_AZ=ap-southeast-1c
```

If you ever provision a brand-new environment (no pre-existing volumes), create fresh volumes as shown
in [Setup](#setup) and look up their IDs once with `aws ec2 describe-volumes --filters
"Name=tag:Name,Values=<name>"`, then replace the fixed IDs above with the new ones — don't re-run that
lookup on every sync, since a duplicate `Name` tag will reintroduce the same ambiguity.

Then sync the Helm releases:

```bash
helmfile -f helm/helmfile.yaml.gotmpl lint #optional
helmfile -f helm/helmfile.yaml.gotmpl sync
```

Validation:

```bash
helmfile -f helm/helmfile.yaml.gotmpl list
kubectl get pods -n kube-system  # shows aws-load-balancer-controller healthy.
kubectl get pods -n external-dns # shows external-dns healthy.
kubectl get pods -n monitoring   # shows prometheus/grafana healthy.

kubectl get pv retained-grafana-pv retained-prometheus-tsdb-pv retained-loki-data-pv retained-alertmanager-data-pv retained-kubecost-local-store-pv
kubectl get pvc -n monitoring
kubectl get pvc -n kubecost
kubectl get pods -n monitoring
kubectl get pods -n kubecost

kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].spec.volumes}'
kubectl get pod -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].spec.volumes}'
kubectl get pod -n monitoring -l app.kubernetes.io/name=loki -o jsonpath='{.items[0].spec.volumes}'
```

### ArgoCD Repo Credential (set up before the Kustomize apply below)

Since this repo is private, ArgoCD needs read-only git credentials to clone it. Generate a deploy key and
register it as an ArgoCD repository credential **before** running the Kustomize apply below — that way
ArgoCD can sync immediately once its bootstrap `Application` is created, instead of sitting in a
transient "repository not found"/auth error until the credential shows up. This only needs to be done
once per environment (i.e. again after a fresh `terraform apply`, since the Secret lives inside the
cluster and doesn't survive a `terraform destroy`):

```bash
ssh-keygen -t ed25519 -C "argocd-ce12-capstone-sandbox-readonly" -f argocd_deploy_key -N ""
gh repo deploy-key add argocd_deploy_key.pub --repo mfaizalbe/ce12-capstone-sandbox --title "argocd-readonly"

kubectl create secret generic repo-ce12-capstone-sandbox \
  -n argocd \
  --from-literal=type=git \
  --from-literal=url=git@github.com:mfaizalbe/ce12-capstone-sandbox.git \
  --from-file=sshPrivateKey=argocd_deploy_key
kubectl label secret repo-ce12-capstone-sandbox -n argocd argocd.argoproj.io/secret-type=repository

rm argocd_deploy_key argocd_deploy_key.pub  # private key only ever lives in the k8s Secret, never in git
```

Create a secret for the Discord webhook URL:

```bash
kubectl -n monitoring create secret generic discord-webhook \
  --from-literal=url='https://discord.com/api/webhooks/<id>/<token>/slack' \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Start Application with Kustomize

```bash
aws eks --region ap-southeast-1 update-kubeconfig --name retail-store-grp5
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=ap-southeast-1
export EKS_CLUSTER_NAME=retail-store-grp5
kubectl kustomize manifests | envsubst '${AWS_ACCOUNT_ID} ${EKS_CLUSTER_NAME} ${AWS_REGION}' | kubectl apply -f -
```

Validation:

```bash
kubectl get all -A
kubectl get application -n argocd retail-store   # should show Synced/Healthy
```

This command also creates the ArgoCD `Application` (`manifests/argocd/application.yaml`), which then
takes over: future commits to `manifests/` on `main` are synced automatically (prune + selfHeal), so you
don't need to re-run this command for app changes going forward. It's still needed for the very first
apply, and works as a manual fallback any time.

---

## Shutdown

Tear everything down in the reverse order it was created (application first, then platform, then infra):

```bash
kubectl delete -k manifests
helmfile -f helm/helmfile.yaml.gotmpl destroy
terraform -chdir=terraform destroy
```

This does **not** delete the S3 buckets or retained EBS volumes from [Setup](#setup) — they're designed
to survive a teardown so dashboards/data/state persist across rebuilds. Delete them manually only if you
want to fully decommission the environment.

---

## Useful Commands

If you're running these in a fresh terminal/session, point kubectl at the cluster first:

```bash
aws eks --region ap-southeast-1 update-kubeconfig --name retail-store-grp5
```

### Get Grafana Admin Password

```bash
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

### Get ArgoCD Admin Password

Username is `admin`.

```bash
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode
```

---

## DEMO: Node Failure Simulation

This uses [AWS Fault Injection Service (FIS)](https://docs.aws.amazon.com/fis/) to terminate 67% of the
instances in the `application` node group on purpose, so you can watch the cluster self-heal and see the
`NodeNotReady`/`RetailStorePodsPending` Prometheus alerts fire
(see [`manifests/alerts/prometheusrule.yaml`](manifests/alerts/prometheusrule.yaml)). The IAM role FIS
assumes is created by Terraform (`fis_role` in [`terraform/iam.tf`](terraform/iam.tf)).

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION="ap-southeast-1"
export FIS_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/retail-store-grp5-fis-role"
export CLUSTER_NAME="retail-store-grp5"
export NODEGROUP_NAME=$(aws eks list-nodegroups --region "$AWS_REGION" --cluster-name "$CLUSTER_NAME" --query "nodegroups[?starts_with(@, '${CLUSTER_NAME}-ng-application')]" --output text)
export NODEGROUP_ARN=$(aws eks describe-nodegroup --region "$AWS_REGION" --cluster-name "$CLUSTER_NAME" --nodegroup-name "$NODEGROUP_NAME" --query 'nodegroup.nodegroupArn' --output text)
```

Create the experiment template (this only defines the experiment, it does not run anything yet):

```bash
export NODE_EXP_ID=$(aws fis create-experiment-template --region "$AWS_REGION" --cli-input-json '{"description":"NodeDeletion","targets":{"target-nodegroup":{"resourceType":"aws:eks:nodegroup","resourceArns":["'$NODEGROUP_ARN'"],"selectionMode":"ALL"}},"actions":{"nodedeletion":{"actionId":"aws:eks:terminate-nodegroup-instances","parameters":{"instanceTerminationPercentage":"67"},"targets":{"Nodegroups":"target-nodegroup"}}},"stopConditions":[{"source":"none"}],"roleArn":"'$FIS_ROLE_ARN'","tags":{"ExperimentSuffix":"DEMO"}}' --output json | jq -r '.experimentTemplate.id')
```

Run it (this actually terminates instances — only do this on a cluster you're OK disrupting):

```bash
export NODE_EXP_ID=EXTEKNnXLxNWUDCmE # when repeating the experiment only
aws fis start-experiment --region "$AWS_REGION" --experiment-template-id "$NODE_EXP_ID" --output json
```
