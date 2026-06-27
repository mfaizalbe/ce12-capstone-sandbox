# Architecture Decision Record (ADR)


# ADR 0007: Use Kubecost for Kubernetes Cost Visibility

## Status

Accepted

## Context

The project runs a multi-namespace EKS cluster with both application and observability workloads, backed
by EC2 nodes, EBS volumes, and an Application Load Balancer. As an SRE capstone, the team wants to
demonstrate not just reliability and observability practices but also cost-awareness — understanding
which namespace, deployment, or workload is driving infrastructure spend.

Key constraints and requirements include:

* AWS Cost Explorer/Billing reports cost at the account/service level, not at the Kubernetes
  namespace/deployment level, so it cannot answer "which microservice is most expensive."
* The team already runs Prometheus (kube-prometheus-stack) for metrics, so any cost tool ideally
  integrates with the existing metrics pipeline rather than requiring a separate one.
* Need to expose a cost dashboard for the team without introducing a new paid SaaS dependency.
* Limited time to integrate yet another tool, so ease of installation (Helm chart, fits the existing
  Helmfile pattern) matters.

## Options Considered

### Option 1: AWS Cost Explorer / Billing Console Only

**Pros**

* No additional installation — already available via the AWS account.
* No extra compute/storage cost to run.

**Cons**

* Cost is broken down by AWS service (EC2, EBS, ALB) or cost-allocation tags at best, not by Kubernetes
  namespace, deployment, or pod — far too coarse to attribute spend to a specific microservice.
* No correlation with cluster utilization metrics (CPU/memory requests vs. usage) to spot
  over-provisioning.
* Doesn't demonstrate Kubernetes-native cost-management practices, which is part of the learning goal.

### Option 2: Kubecost (Chosen)

**Pros**

* Purpose-built for Kubernetes cost allocation: breaks down spend by namespace, deployment, label, and
  more, directly mapping to the project's per-service namespace layout (carts, catalog, checkout, orders,
  ui).
* Integrates with the existing Prometheus installation (`needs: monitoring/prometheus` in
  `helm/helmfile.yaml.gotmpl`) rather than requiring a separate metrics pipeline.
* Installs via Helm like every other platform component, fitting the established Helmfile pattern, and is
  exposed internally via the same Gateway API/HTTPRoute mechanism as other dashboards
  (`manifests/kubecost/`).
* Free tier is sufficient for a single, small, non-production cluster.

**Cons**

* Adds another stateful component (EBS-backed) to provision, retain storage for, and keep running.
* Another Helm release and CRD/dependency chain (depends on Prometheus being synced first) to sequence
  correctly in Helmfile.
* Free tier has data retention and feature limits compared to the paid tiers, though sufficient for this
  project's scope.

## Decision

The team chose to install Kubecost via Helmfile (depending on the Prometheus release) and expose it
through the same Gateway API/HTTPRoute pattern used for other dashboards, rather than relying on AWS
Cost Explorer alone.

This decision was made because Kubecost provides namespace/deployment-level cost attribution that maps
directly onto the project's per-service structure, integrates with the Prometheus metrics already being
collected, and reinforces the SRE capstone's goal of demonstrating cost-awareness alongside reliability
and observability.

## Consequences

### Makes Easier

* Attributing infrastructure cost to specific microservices/namespaces.
* Spotting over-provisioned CPU/memory requests using the same data Kubecost surfaces.
* Demonstrating a complete SRE story (reliability + observability + cost) in the capstone.

### Rules Out

* Relying solely on AWS-account-level billing views for cost analysis.
* Installing Kubecost independently of the Prometheus release (it depends on `monitoring/prometheus`
  being synced first).
