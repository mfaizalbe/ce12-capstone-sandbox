# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## What this repo is

SCTP CE12 DevOps Capstone sandbox: a retail-store microservices app deployed to AWS EKS, provisioned with
Terraform, with platform services (load balancer controller, external-dns, Prometheus/Grafana/Loki, OTel,
Kubecost) installed via Helmfile, and the application + alerting installed via Kustomize. There is no
application source code in this repo — `manifests/` only contains Kubernetes manifests referencing
pre-built container images for each service (carts, catalog, checkout, orders, ui).

Cluster name: `retail-store-grp5`, region `ap-southeast-1`.

## Architecture / deployment order

There are three independent layers that must be applied in order: **Terraform → Helmfile → Kustomize**.
Each layer has a distinct responsibility and they are not interchangeable:

1. **Terraform (`terraform/`)** — provisions the VPC (`vpc.tf`), EKS cluster and two managed node groups
   (`eks.tf`: `application` node group untainted, `observability` node group pinned to AZ `ap-southeast-1c`
   and tainted `workload=observability:NoSchedule` so only observability pods land there), the EBS CSI
   addon (`main.tf`), and IAM/IRSA roles for service accounts (`iam.tf`: load balancer controller,
   external-dns, ebs-csi, fluent-bit, grafana (CloudWatch read), loki (S3), and an AWS FIS role used for
   chaos/failure-injection demos). State is remote: S3 bucket `capstone-project-group5`, key
   `eks/default/terraform.tfstate`, with S3-native locking (`use_lockfile`).

2. **Helmfile (`helm/helmfile.yaml.gotmpl`)** — installs cluster controllers/operators and their CRDs:
   `aws-load-balancer-controller` (presync hook applies Gateway API CRDs from `helm/crds`),
   `external-dns`, `prometheus` (kube-prometheus-stack; presync hooks (a) apply retained EBS PVs from
   `helm/retained-storage.yaml` via `envsubst` using the `*_EBS_VOLUME_ID`/`*_EBS_AZ` env vars, and (b)
   server-side apply the chart's CRDs before sync), `loki`, `opentelemetry-operator`, `kubecost`
   (`needs: monitoring/prometheus`), and `argocd` (GitOps continuous delivery for the app layer — see
   below). Values live in `helm/values/*.yaml` (some are `.gotmpl` and need env vars like
   `AWS_ACCOUNT_ID`, `VPC_ID` substituted by helmfile/envsubst).

3. **Kustomize (`manifests/`)** — installs application workloads and custom resources that depend on the
   CRDs/controllers from step 2: one directory per namespace (`catalog`, `carts`, `checkout`, `orders`,
   `ui`), plus `fluentbit`, `adot` (OpenTelemetryCollector), `grafana` (HTTPRoute), `load-gen` (CronJob
   traffic generator), `kubecost` (HTTPRoute), `alerts` (PrometheusRule), and `argocd` (HTTPRoute +
   the bootstrap `Application` CR — see "GitOps via ArgoCD" below). The root `manifests/kustomization.yaml`
   lists all of these. Applying it requires `envsubst` for `AWS_ACCOUNT_ID`, `EKS_CLUSTER_NAME`,
   `AWS_REGION` (see README "Start Application with Kustomize").

Each app namespace under `manifests/<svc>/` follows the same shape: `namespace.yaml`, `serviceAccount.yaml`,
`configMap.yaml`, `deployment.yaml`, `service.yaml`, and — for stateful services — a paired
`deployment-<db>.yaml`/`service-<db>.yaml` (e.g. carts uses an in-cluster DB, orders uses postgresql,
checkout uses redis, catalog uses a MySQL StatefulSet).

Ingress is via Gateway API (`gatewayclass.yaml`, `gateway.yaml`, `httproute.yaml`,
`loadbalancerconfig.yaml`, `targetgrpconf.yaml` in `manifests/ui/`), not classic Ingress — this is why the
ALB controller's Gateway CRDs must be present before manifests apply.

## GitOps via ArgoCD

ArgoCD manages only the **app layer** (the contents of `manifests/`) — Terraform and Helmfile are still
applied manually as described above; ArgoCD does not manage platform/Helm releases.

- Installed via Helmfile (`argocd` release, namespace `argocd`), exposed via Gateway API HTTPRoute
  (`manifests/argocd/httproute.yaml`, host `grp5-argocd.sctp-sandbox.com`), same pattern as Grafana/Kubecost.
  `helm/values/argocd.yaml` sets `server.insecure: "true"` because the shared ALB Gateway listener is
  plain HTTP (no TLS) — without this, `argocd-server`'s default HTTPS redirect breaks behind it.
- `manifests/argocd/application.yaml` is a self-managing `Application` CR: it points at this repo's
  `manifests/` path with `automated: {prune: true, selfHeal: true}`. It is applied as part of the normal
  `kubectl apply -k manifests` step (no separate bootstrap command) — from then on, ArgoCD watches this
  repo and auto-syncs any future commits to `manifests/` itself.
- Because ArgoCD's repo-server runs a plain `kustomize build` (no `envsubst` pipe), the few manifests that
  used to rely on deploy-time `envsubst` for `AWS_ACCOUNT_ID`/`EKS_CLUSTER_NAME`/`AWS_REGION`
  (`manifests/adot/serviceaccount.yaml`, `manifests/adot/opentelemetrycollector.yaml`) were hardcoded
  instead, since this is a single fixed cluster/account. `manifests/fluentbit/fluent-bit.yaml` did **not**
  need this — its `${AWS_REGION}`/`${CLUSTER_NAME}`/`${HOST_NAME}` placeholders are resolved by Fluent
  Bit itself from real container env vars at runtime, independent of any deploy-time substitution.
- Team access: same model as Grafana — a single shared admin login, password pulled from a generated
  k8s Secret (see Operational helpers below) and shared with the team out-of-band.

## Common commands

All commands assume `terraform`, `helmfile`, `kubectl`, `aws` CLI, and `envsubst` are installed and AWS
credentials are configured.

### Provision infra + platform

```bash
terraform -chdir=terraform init
terraform -chdir=terraform apply

aws eks --region ap-southeast-1 update-kubeconfig --name retail-store-grp5
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export VPC_ID=$(aws eks describe-cluster --name retail-store-grp5 --region ap-southeast-1 --query 'cluster.resourcesVpcConfig.vpcId' --output text)
# plus PROMETHEUS_EBS_VOLUME_ID / _AZ, LOKI_EBS_VOLUME_ID / _AZ, GRAFANA_EBS_VOLUME_ID / _AZ,
# ALERTMANAGER_EBS_VOLUME_ID / _AZ, KUBECOST_EBS_VOLUME_ID / _AZ (see README for the EBS volumes
# these refer to and the `aws ec2 create-volume` commands that create them)

helmfile -f helm/helmfile.yaml.gotmpl lint   # optional
helmfile -f helm/helmfile.yaml.gotmpl sync
helmfile -f helm/helmfile.yaml.gotmpl list   # validate
```

### Deploy the application

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=ap-southeast-1
export EKS_CLUSTER_NAME=retail-store-grp5
kubectl kustomize manifests | envsubst '${AWS_ACCOUNT_ID} ${EKS_CLUSTER_NAME} ${AWS_REGION}' | kubectl apply -f -
```

This also creates the ArgoCD `Application` (`manifests/argocd/application.yaml`), which then takes over:
future commits to `manifests/` are auto-synced by ArgoCD and don't need this command re-run. It's still
useful for the very first apply, and as a manual fallback.

To preview/validate a single manifest subdirectory without applying, e.g.:

```bash
kubectl kustomize manifests/carts
```

### Tear down (reverse order of apply)

```bash
kubectl delete -k manifests
helmfile -f helm/helmfile.yaml.gotmpl destroy
terraform -chdir=terraform destroy
```

### Operational helpers

```bash
# Grafana admin password
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# ArgoCD admin password (username: admin)
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode
```

Chaos/failure-injection demo (AWS FIS terminates a node in the `application` node group to exercise the
`NodeNotReady` / `RetailStorePodsPending` alerts in `manifests/alerts/prometheusrule.yaml`):

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export FIS_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/retail-store-grp5-fis-role"
export NODE_EXP_ID=$(aws fis create-experiment-template --cli-input-json '...' --output json | jq -r '.experimentTemplate.id')
aws fis start-experiment --experiment-template-id $NODE_EXP_ID --output json
```

## Observability stack

- **Metrics**: ADOT OpenTelemetryCollector (`manifests/adot/`) runs a `kubernetes-pods` scrape job and
  remote-writes into the in-cluster Prometheus (installed via Helmfile). Query via Prometheus or Grafana.
- **Logs**: Fluent Bit (`manifests/fluentbit/`) ships logs; Loki (Helmfile-installed) stores them.
- **Dashboards**: importable JSON in `grafana/dashboards/` (`retail_store_app.json`,
  `retail_store_logs.json`, `demo.json`). `docs/app_metrics.md` documents per-service metric families
  (carts/orders/ui are Spring Boot/JVM, catalog is Go/Gin, checkout is Node.js), starter PromQL queries,
  and a full dashboard panel blueprint — consult it before building new panels or alerts so naming/labels
  stay consistent (`namespace`, `pod`, `job="kubernetes-pods"`).
- **Alerts**: `manifests/alerts/prometheusrule.yaml` — PrometheusRules **must** carry the label
  `release: prometheus` or kube-prometheus-stack's Prometheus will silently ignore them (it only selects
  rules matching its release name).
- **Costing**: Kubecost installed via Helmfile, exposed via HTTPRoute in `manifests/kubecost/`.
- `docs/installation.md` explains the CRD-ownership split in detail: Helmfile/presync hooks own
  controller CRDs (Gateway API, ALB, Prometheus Operator, OTel Operator); Kustomize only ever creates
  *instances* of those CRDs (e.g. `OpenTelemetryCollector`, `HTTPRoute`, `PrometheusRule`), never new CRD
  definitions. If kustomize apply fails with a missing-CRD error, the fix is almost always "the Helmfile
  stage didn't fully sync first."

## Conventions when editing manifests

- Keep the per-namespace file layout consistent (`namespace.yaml`, `serviceAccount.yaml`, `configMap.yaml`,
  `deployment.yaml`, `service.yaml`, `kustomization.yaml`, and DB pair if stateful) — every existing
  service follows this pattern.
- Namespaces carry the label `app.kubernetes.io/created-by: eks-workshop` (this repo originated from the
  AWS EKS Workshop retail-store-sample-app reference architecture).
- New Helm releases go in `helm/helmfile.yaml.gotmpl`; if a release needs CRDs not already installed,
  add a `presync` hook the same way `aws-load-balancer-controller` and `prometheus` do, rather than
  relying on `--skip-crds` chart defaults (helmDefaults already sets `--skip-crds` globally).
- Anything that needs an AWS resource ID/ARN at apply time (EBS volume IDs, account ID, VPC ID) is passed
  through as an env var and substituted with `envsubst` in a `.gotmpl`/template file — follow that pattern
  rather than hardcoding values into manifests, **except** in `manifests/` itself: that tree is synced
  directly by ArgoCD's `kustomize build` (no `envsubst` pass), so `AWS_ACCOUNT_ID`/`EKS_CLUSTER_NAME`/
  `AWS_REGION` must be literal there (see "GitOps via ArgoCD" above). The `.gotmpl` env-var pattern still
  applies everywhere under `helm/`.
