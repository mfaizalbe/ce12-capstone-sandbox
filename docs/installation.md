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
kubectl apply -k manifests
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
kubectl apply -k manifests

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
   - `kubectl apply -k manifests`
4. Teardown is repeatable without subnet/IGW dependency violations.

## Quick execution checklist

1. Step 1 Terraform decoupled.
2. Step 2 Helmfile introduced and validated.
3. Step 3 Kustomize app flow validated.
4. Step 4 one-command workflow added.
5. Step 5 repo structure Argo-ready.
6. Step 6 Argo manual sync working.
7. Step 7 Argo auto-sync enabled gradually.
