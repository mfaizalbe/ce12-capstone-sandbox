# Architecture Decision Record (ADR)


# ADR 0003: Split Deployment Responsibility Between Helmfile and Kustomize

## Status

Accepted

## Context

The platform has two distinct categories of Kubernetes resources to manage: cluster-wide
controllers/operators with their CRDs (AWS Load Balancer Controller, external-dns, kube-prometheus-stack,
Loki, OpenTelemetry Operator, Kubecost, ArgoCD), and the retail-store application workloads plus the custom
resources that depend on those controllers (Deployments, Services, `HTTPRoute`, `OpenTelemetryCollector`,
`PrometheusRule`). The team needed a way to manage both categories repeatably across a one-month project
with five contributors.

Key constraints and requirements include:

* Controllers and their CRDs change rarely and are typically installed from third-party Helm charts.
* Application manifests and custom resource instances change frequently as the team iterates.
* Some application-layer resources (e.g. `OpenTelemetryCollector`, `HTTPRoute`, `PrometheusRule`) require
  CRDs that only the controller layer can install — ordering between the two layers matters.
* Need for environment-specific value substitution (AWS account ID, VPC ID, EBS volume IDs, cluster name,
  region) without hardcoding into manifests.
* Desire to avoid one large, monolithic Helm umbrella chart or one large raw-manifest directory that mixes
  concerns.

## Options Considered

### Option 1: Manage Everything with Helm/Helmfile

**Pros**

* Single tool, single mental model, single `helmfile sync` command for the whole stack.
* Built-in templating, value layering, and release lifecycle hooks.
* Avoids needing `envsubst` for plain-manifest substitution.

**Cons**
* The retail-store application has no existing Helm chart in this repo; would require authoring and
  maintaining charts for every microservice rather than using the plain manifests provided.
* Helm's templating model is heavier than needed for largely-static per-namespace manifests.
* Mixes infrequently-changing infrastructure releases with frequently-changing application manifests in
  the same release lifecycle, increasing the blast radius of `helmfile sync`.

### Option 2: Manage Everything with Kustomize

**Pros**

* Single tool, plain YAML, no templating language to learn.
* Works well for the application manifests, which are already structured as plain YAML per namespace.

**Cons**

* Kustomize has no native concept of Helm chart installation, release ordering, or presync hooks; it
  cannot install the third-party controllers (ALB controller, kube-prometheus-stack, Loki, OTel Operator,
  Kubecost) without vendoring their rendered manifests, which would be brittle to upgrade.
* Loses the value-layering and lifecycle hooks Helm charts provide for complex upstream dependencies.

### Option 3: Split — Helmfile for Controllers/CRDs, Kustomize for Application Instances

**Pros**

* Each tool is used for what it is best at: Helmfile/Helm for installing and upgrading third-party charts
  with CRDs and lifecycle hooks (`presync` for CRD application and retained-volume binding); Kustomize for
  composing and overlaying the team's own plain-YAML application manifests.
* Clear ownership boundary: controllers and CRD definitions belong to Helmfile; CRD *instances*
  (`HTTPRoute`, `OpenTelemetryCollector`, `PrometheusRule`) belong to Kustomize. Documented explicitly in
  `docs/installation.md`.
* Matches the natural change cadence of each layer — infrequent infra upgrades vs. frequent app changes —
  so day-to-day iteration only touches `kubectl kustomize manifests | envsubst | kubectl apply`.
* Failure mode is predictable and debuggable: "Kustomize apply failed with a missing CRD" almost always
  means "Helmfile didn't fully sync first," giving a clear troubleshooting heuristic.

**Cons**

* Two tools instead of one, with a strict ordering dependency (Terraform → Helmfile → Kustomize) that
  must be communicated and followed correctly.
* `envsubst` is needed in both layers for environment-specific values, rather than relying on a single
  templating mechanism.
* New contributors need to understand the CRD-ownership split before they can safely add new resources.

## Decision

The team chose to split deployment responsibility: Helmfile (`helm/helmfile.yaml.gotmpl`) installs
third-party controllers and their CRDs, while Kustomize (`manifests/`) installs the application workloads
and CRD instances that depend on them, applied strictly after Helmfile in the Terraform → Helmfile →
Kustomize order.

This decision was made because no existing Helm chart covers the retail-store application, and authoring
one would have added unnecessary complexity for a one-month project. Kustomize's plain-YAML model fits the
application manifests well, while Helmfile's chart/CRD/hook model is the most direct way to install and
manage third-party platform components. Keeping infrastructure-owned CRDs separate from application-owned
CRD instances also gives the team an easy mental model and a reliable troubleshooting heuristic for
ordering failures.

## Consequences

### Makes Easier

* Iterating on application manifests independently of platform/controller upgrades.
* Diagnosing missing-CRD errors ("Helmfile stage didn't fully sync first").
* Adding new platform components without touching application manifests, and vice versa.
* Keeping each tool's responsibility narrow and well-documented (`docs/installation.md`).

### Rules Out

* A single `helmfile sync` or single `kubectl apply -k` command standing up the entire stack end-to-end.
* Treating application manifests as Helm chart templates.
* Vendoring rendered third-party controller manifests into Kustomize to avoid using Helm.
