# Architecture Decision Record (ADR)


# ADR 0004: Use Prometheus, Grafana, Loki, and OpenTelemetry for Observability

## Status

Accepted

## Context

The capstone is explicitly an SRE-focused project: it needs to demonstrate metrics, logs, and alerting
across five retail-store microservices (carts, catalog, checkout, orders, ui) running on EKS, within a
one-month timeframe and a five-person team with limited budget for managed SaaS observability tools.

Key constraints and requirements include:

* Need metrics (per-service and cluster-level), logs, and alerting, not just one pillar.
* Must integrate with Kubernetes-native scraping/service discovery.
* Cost needs to stay low — the team is using self-hosted EBS-backed storage rather than a paid SaaS tier.
* Must support demonstrating SRE practices: dashboards, PromQL alerting rules, and failure-injection
  scenarios that alerts should catch (`NodeNotReady`, `RetailStorePodsPending`).
* Limited time to learn and integrate tooling, favoring well-documented, widely-adopted open-source
  components over building bespoke pipelines.

## Options Considered

### Option 1: AWS-Native (CloudWatch Container Insights + CloudWatch Logs)

**Pros**

* No additional components to install or operate; tightly integrated with EKS and IAM.
* No self-managed storage (EBS volumes, retention) to provision.

**Cons**

* CloudWatch dashboards and alerting are less flexible than Grafana/PromQL for the kind of ad-hoc,
  per-service SRE dashboards this project wants to demonstrate.
* Costs scale with log/metric volume and can be harder to predict than self-hosted storage on
  already-provisioned EBS volumes.
* Less transferable experience — Prometheus/Grafana/Loki skills are more broadly applicable across
  employers than CloudWatch-specific tooling.

### Option 2: Commercial SaaS (Datadog, New Relic, etc.)

**Pros**

* Turnkey metrics, logs, tracing, and alerting with polished UIs and minimal setup.
* Strong out-of-the-box Kubernetes integrations.

**Cons**

* Cost is prohibitive for a student capstone with no budget for commercial licensing.
* Reduces hands-on learning of how the observability pipeline is actually wired together (scraping,
  remote-write, log shipping), which is a core learning objective.

### Option 3: Self-Hosted Prometheus + Grafana + Loki + OpenTelemetry (Chosen)

**Pros**

* Fully open-source, no licensing cost; only pays for the underlying EBS volumes and EC2/EKS compute
  already provisioned.
* `kube-prometheus-stack` is the de facto standard for in-cluster Prometheus/Grafana/Alertmanager and
  ships with sane defaults and CRDs (`PrometheusRule`, `ServiceMonitor`) for declarative alerting.
* Loki pairs naturally with Grafana for logs, using the same query/dashboard surface as metrics.
* OpenTelemetry (via the OpenTelemetry Operator and an `OpenTelemetryCollector` instance in
  `manifests/adot/`) gives a vendor-neutral collection pipeline with two outputs: metrics are scraped
  from pods and remote-written to Prometheus; distributed traces are collected via OTLP from
  auto-instrumented services and exported to AWS X-Ray (see [[0010-otel-auto-instrumentation]]).
* PromQL, Grafana, and OTel are widely used in industry, maximizing transferable skill-building for the
  team.

**Cons**

* Requires self-managing storage: retained EBS volumes per component (Prometheus, Loki, Grafana,
  Alertmanager, Kubecost) provisioned ahead of time and bound via presync hooks in Helmfile.
* More moving parts to install and keep in sync (Helm releases, CRDs, presync hooks) than a managed
  alternative.
* The team owns upgrade and version-compatibility management across kube-prometheus-stack, Loki, and the
  OTel Operator.

## Decision

The team chose to self-host Prometheus, Grafana, Loki, and the OpenTelemetry Operator/Collector
(installed via Helmfile, instantiated via Kustomize) as the observability stack, with PrometheusRule-based
alerting (`manifests/alerts/prometheusrule.yaml`) tied to the `release: prometheus` label required by
kube-prometheus-stack's rule selector.

This decision was made to keep costs near zero beyond already-provisioned infrastructure, to maximize
hands-on learning of how a production-style observability pipeline is assembled end-to-end, and because
this combination is the de facto open-source standard for Kubernetes observability, making it the most
transferable choice for the team's SRE learning objectives.

## Consequences

### Makes Easier

* Building custom Grafana dashboards (`grafana/dashboards/*.json`) and PromQL alerts tailored to the
  retail-store services, documented per-service in `docs/app_metrics.md`.
* Demonstrating the full alerting lifecycle, including failure-injection scenarios (AWS FIS) that should
  trigger specific PrometheusRules.
* Keeping observability infrastructure costs predictable (EBS storage instead of usage-based SaaS
  billing).

### Rules Out

* Zero-setup, fully managed observability with no self-hosted components.
* Avoiding the need to provision and bind retained EBS volumes per observability component.
* Skipping the CRD-ownership sequencing constraint (Prometheus Operator and OTel Operator CRDs must exist
  before `PrometheusRule`/`OpenTelemetryCollector` instances can be applied).
