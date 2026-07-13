# Architecture Decision Record (ADR)


# ADR 0009: Use ArgoCD for GitOps Continuous Delivery of the Application Layer

## Status

Accepted

## Context

The platform has three deployment layers (Terraform → Helmfile → Kustomize). The app layer (`manifests/`)
changes frequently as the team iterates on deployments, and manually running `kubectl apply -k manifests`
after every commit is error-prone and easy to forget — the cluster can silently drift from what is in Git.

Key constraints and requirements include:

* The team needs the cluster to automatically reflect whatever is committed to `manifests/` in the main
  branch, without requiring someone to manually run `kubectl apply` after every merge.
* The tool must support Kustomize natively, since the app layer uses Kustomize for manifest composition.
* The solution must work with a private GitHub repository.
* ArgoCD itself must be installed via Helmfile (like the other platform controllers), not managed by
  itself — this creates a one-time bootstrap step where the initial `kubectl apply -k manifests` is still
  run manually.
* The ALB Gateway listener is plain HTTP (no TLS), which affects how the ArgoCD UI is exposed.

## Options Considered

### Option 1: Manual `kubectl apply` on Every Change

**Pros**

* No additional tooling; uses the same `kubectl kustomize manifests | envsubst | kubectl apply` command
  already established for the initial deployment.

**Cons**

* Requires every team member to remember to apply after merging — easy to forget, leading to drift
  between Git and the cluster.
* No audit trail of what was applied when, or by whom.
* Breaks the "Git is the source of truth" principle: the cluster state can silently diverge.

### Option 2: Flux

**Pros**

* Lightweight GitOps operator with strong Kustomize support and a minimal footprint.
* Fully declarative — Flux itself is managed as Kubernetes resources.

**Cons**

* Less team familiarity with Flux compared to ArgoCD.
* Flux's UI is minimal; ArgoCD's web UI provides better visibility into sync status, resource health,
  and drift — useful for a capstone demo.

### Option 3: ArgoCD (Chosen)

**Pros**

* Rich web UI showing sync status, resource health, and diff between desired and live state — valuable
  for a capstone demo audience.
* Native Kustomize support: ArgoCD's repo-server runs `kustomize build` directly, no extra wrappers.
* Self-managing bootstrap pattern: the `Application` CR (`manifests/argocd/application.yaml`) is applied
  as part of the initial `kubectl apply -k manifests`, after which ArgoCD takes over and manages the
  entire `manifests/` tree including itself.
* `automated: {prune: true, selfHeal: true}` means deleted manifests are pruned from the cluster and any
  manual drift is corrected automatically, within approximately 3 minutes of a commit.

**Cons**

* Heavier than Flux — ArgoCD installs several components (repo-server, application-controller,
  API server, Redis) adding to cluster resource consumption.
* ArgoCD's repo-server runs a plain `kustomize build` with no `envsubst` pass, so manifests in
  `manifests/` cannot use `${AWS_ACCOUNT_ID}`, `${EKS_CLUSTER_NAME}`, or `${AWS_REGION}` placeholders —
  these must be hardcoded in the manifests (see [[0003-helmfile-kustomize-split]]).
* Requires a deploy key to clone a private repository: an SSH key must be generated, registered as a
  GitHub deploy key, and stored as a Kubernetes Secret in the `argocd` namespace before the first apply.

## Decision

The team chose ArgoCD, installed via Helmfile (`argocd` release, namespace `argocd`) and exposed via
Gateway API HTTPRoute (`manifests/argocd/httproute.yaml`, host `grp5-argocd.sctp-sandbox.com`).

ArgoCD is configured with `server.insecure: "true"` in `helm/values/argocd.yaml` because the shared ALB
Gateway listener is plain HTTP — without this, ArgoCD's default HTTPS redirect causes an infinite redirect
loop behind the HTTP-only listener.

The `Application` CR (`manifests/argocd/application.yaml`) points at `manifests/` on the `main` branch
with `automated: {prune: true, selfHeal: true}`. It is applied once as part of the initial
`kubectl apply -k manifests` bootstrap, after which ArgoCD self-manages and auto-syncs all future commits
to `manifests/` without any manual intervention.

## Consequences

### Makes Easier

* Deploying application changes: commit to `manifests/`, push to main, ArgoCD syncs within ~3 minutes.
* Detecting drift: ArgoCD's UI shows immediately if the cluster state diverges from Git.
* Demonstrating GitOps to a capstone audience via ArgoCD's real-time sync dashboard.

### Rules Out

* Using `envsubst` placeholders (`${AWS_ACCOUNT_ID}`, `${EKS_CLUSTER_NAME}`, `${AWS_REGION}`) in any
  manifest under `manifests/` — these must be hardcoded since ArgoCD's repo-server has no envsubst step.
* Applying `manifests/` changes manually after the initial bootstrap (ArgoCD will overwrite manual changes
  within ~3 minutes due to `selfHeal: true`).
