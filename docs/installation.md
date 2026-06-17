# Installation: Terraform + Helmfile + Kustomize

## Step 1 - Terraform Initialisation

```bash
cd terraform
terraform init
terraform apply
```

## Step 2 - Introduce Helmfile for platform charts

### Runtime variables required by Helmfile:

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export VPC_ID=$(aws eks describe-cluster --name retail-store-grp5 --region ap-southeast-1 --query 'cluster.resourcesVpcConfig.vpcId' --output text)
```

Actions:

1. Add `helmfile.yaml.gotmpl` with releases for:
   - aws-load-balancer-controller
   - external-dns
   - kube-prometheus-stack
2. Reference IRSA role ARNs and VPC ID through runtime environment variables.
3. Pin chart versions.
4. Add release ordering with `needs`.
5. Keep CRD ownership split to avoid conflicts:
   - Helmfile presync hook applies Gateway API standard CRDs.
   - aws-load-balancer-controller chart installs AWS Gateway CRDs.

Commands:

```bash
# Export the account and current VPC ID for this cluster:
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export VPC_ID=$(aws eks describe-cluster --name retail-store-grp5 --region ap-southeast-1 --query 'cluster.resourcesVpcConfig.vpcId' --output text)

# Then run Helmfile:
helmfile -f helm/helmfile.yaml.gotmpl lint
helmfile -f helm/helmfile.yaml.gotmpl sync
helmfile -f helm/helmfile.yaml.gotmpl list
```

Validation:

- `kubectl get pods -n kube-system` shows aws-load-balancer-controller healthy.
- `kubectl get pods -n external-dns` shows external-dns healthy.
- `kubectl get pods -n monitoring` shows prometheus/grafana healthy.

Rollback:

```bash
helmfile -f helm/helmfile.yaml.gotmpl destroy
```

## Step 3 - Keep applications on Kustomize

Objective:

- Continue app delivery with Kustomize while platform is on Helmfile.

Actions:

1. Keep application manifests under `manifests/`.
2. Ensure app deploy command remains stable.
3. Ensure app teardown is explicit and happens before infra destroy.

Commands:

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=ap-southeast-1
export EKS_CLUSTER_NAME=retail-store-grp5
kubectl kustomize manifests | envsubst '${AWS_ACCOUNT_ID} ${EKS_CLUSTER_NAME} ${AWS_REGION}' | kubectl apply -f -
```

Validation:

- App endpoints are reachable.
- Gateway and target group health stabilize.

Rollback:

- Re-apply previous known-good manifest revision.

## Step 4 - Add operator entrypoints (one-command workflows)

Objective:

- Standardize day-2 operations and enforce lifecycle order.

Actions:

1. Add `Makefile` targets:
   - `bootstrap`
   - `platform-sync`
   - `apps-sync`
   - `teardown`
2. Use strict order in teardown:
   1. app delete
   2. helmfile destroy
   3. terraform destroy

Suggested command flow:

```bash
# bootstrap
terraform -chdir=terraform apply
aws eks --region <region> update-kubeconfig --name <cluster_name>
helmfile -f helm/helmfile.yaml.gotmpl sync
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=<region>
export EKS_CLUSTER_NAME=<cluster_name>
kubectl kustomize manifests | envsubst '${AWS_ACCOUNT_ID} ${EKS_CLUSTER_NAME} ${AWS_REGION}' | kubectl apply -f -

# teardown
kubectl delete -k manifests
helmfile -f helm/helmfile.yaml.gotmpl destroy
terraform -chdir=terraform destroy
```

Validation:

- Repeatable bootstrap/teardown without orphan ENIs/ALBs.

Rollback:

- Run steps individually to isolate failure point.

## Step 5 - Restructure repo for Argo CD compatibility

Objective:

- Prepare folders so Argo can consume existing config with minimal changes.

Recommended target layout:

```text
platform/
  helmfile.yaml
  values/
apps/
  base/
  overlays/
    dev/
    prod/
argocd/
  projects/
  applications/
```

Actions:

1. Move `deploy/` to `platform/` (optional but recommended).
2. Convert `manifests/` into base + overlays where practical.
3. Keep environment-specific values in overlays/values files.

Validation:

- Existing Helmfile and Kustomize workflows still work after moves.

Rollback:

- Revert folder moves in git.

## Step 6 - Introduce Argo CD in manual-sync mode

Objective:

- Start GitOps with low risk.

Actions:

1. Install Argo CD (via Helmfile release or direct Helm).
2. Create Argo Project and Applications for:
   - platform charts
   - application kustomize overlays
3. Set `syncPolicy` to manual first.

Validation:

- Argo UI shows desired vs live state correctly.
- Manual sync works and produces expected resources.

Rollback:

- Disable/scale down Argo CD and continue Helmfile + kubectl workflows.

## Step 7 - Enable automated GitOps gradually

Objective:

- Hand over deployment reconciliation to Argo CD.

Actions:

1. Enable auto-sync for non-critical apps first.
2. Enable prune and self-heal after observation window.
3. Add sync waves and health checks where needed.

Validation:

- Drift is auto-corrected without outages.
- Deployments from git are predictable and auditable.

Rollback:

- Turn off auto-sync and return to manual sync quickly.

## Definition of done (intermediate stage)

This transition stage is complete when:

1. Terraform only manages infrastructure and IAM.
2. Helm charts are deployed with one command:
   - `helmfile -f helm/helmfile.yaml.gotmpl sync`
3. Apps deploy with one command:
   - `kubectl kustomize manifests | envsubst '${AWS_ACCOUNT_ID} ${EKS_CLUSTER_NAME} ${AWS_REGION}' | kubectl apply -f -`
4. Teardown is repeatable without subnet/IGW dependency violations.

## Quick execution checklist

1. Step 1 Terraform decoupled.
2. Step 2 Helmfile introduced and validated.
3. Step 3 Kustomize app flow validated.
4. Step 4 one-command workflow added.
5. Step 5 repo structure Argo-ready.
6. Step 6 Argo manual sync working.
7. Step 7 Argo auto-sync enabled gradually.

# Helm stage installs these charts:

aws-load-balancer-controller
external-dns
prometheus (kube-prometheus-stack)
loki
opentelemetry-operator
CRDs installed as part of Helm stage and hooks

From your current flow, these CRD groups are installed before/during Helm:

Gateway API + AWS Gateway CRDs from manifests/crds (via ALB presync hook in Helmfile)
gatewayclasses.gateway.networking.k8s.io
gateways.gateway.networking.k8s.io
grpcroutes.gateway.networking.k8s.io
httproutes.gateway.networking.k8s.io
referencegrants.gateway.networking.k8s.io
listenerruleconfigurations.gateway.k8s.aws
loadbalancerconfigurations.gateway.k8s.aws
targetgroupconfigurations.gateway.k8s.aws
AWS Load Balancer Controller CRDs (chart-managed)
ingressclassparams.elbv2.k8s.aws
targetgroupbindings.elbv2.k8s.aws
Prometheus Operator CRDs (via prometheus presync hook from chart CRDs)
alertmanagerconfigs.monitoring.coreos.com
alertmanagers.monitoring.coreos.com
podmonitors.monitoring.coreos.com
probes.monitoring.coreos.com
prometheusagents.monitoring.coreos.com
prometheuses.monitoring.coreos.com
prometheusrules.monitoring.coreos.com
scrapeconfigs.monitoring.coreos.com
servicemonitors.monitoring.coreos.com
thanosrulers.monitoring.coreos.com
OpenTelemetry Operator CRDs (chart resources)
instrumentations.opentelemetry.io
opampbridges.opentelemetry.io
opentelemetrycollectors.opentelemetry.io
targetallocators.opentelemetry.io
What is left for manifests stage

# Kustomize

When you run the Kustomize manifests apply, it mainly installs app/platform resources, not new CRD definitions (in your current split). That includes:

Application namespaces, deployments, services, configmaps, secrets
carts, catalog, checkout, orders, ui, load-gen, fluentbit, grafana route pieces, etc.
Gateway/GatewayClass/HTTPRoute/TargetGroup config custom resources
these rely on CRDs already installed in Helm stage/hooks.
ADOT custom resources
notably OpenTelemetryCollector objects in manifests/adot (CRD already present from opentelemetry-operator chart).
So practical summary:

Helm stage = controllers/operators + required CRDs.
Manifests stage = workload resources and custom resources that depend on those CRDs/controllers.

# Presync Hooks

presync hook is a Helmfile lifecycle hook that runs before Helm installs/upgrades a specific release.

In your file helmfile.yaml.gotmpl, it is used to enforce prerequisites:

For aws-load-balancer-controller
presync runs kubectl apply -k ../manifests/crds
Purpose: install Gateway/API CRDs before chart resources that depend on them
For prometheus
presync runs helm show crds ... | kubectl apply --server-side -f -
Purpose: install monitoring.coreos.com CRDs before kube-prometheus-stack resources (PrometheusRule, ServiceMonitor, etc.)
So conceptually:

needs controls release-to-release order.
presync prepares dependencies for a release right before that release runs.
It is triggered by Helmfile sync, not by Kustomize directly.
