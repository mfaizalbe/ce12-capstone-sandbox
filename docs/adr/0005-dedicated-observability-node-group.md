# Architecture Decision Record (ADR)


# ADR 0005: Isolate Observability Workloads on a Dedicated, Tainted Node Group

## Status

Accepted

## Context

The EKS cluster runs both the retail-store application workloads and the observability stack
(Prometheus, Grafana, Loki, Alertmanager, OTel Collector, Kubecost). The team needed to decide whether
these workloads should share the same EC2 node group or be placed on separate node groups.

Key constraints and requirements include:

* Observability components (especially Prometheus and Loki) are stateful, EBS-backed, and sensitive to
  being evicted or rescheduled across availability zones (an EBS volume can only attach within its own
  AZ).
* The team runs a chaos/failure-injection demo (AWS FIS) that terminates a node in the application node
  group to validate `NodeNotReady` / `RetailStorePodsPending` alerts — this must not also take down the
  monitoring stack that is supposed to detect and alert on the failure.
* Limited cluster size (`t3.medium` instances, small min/max/desired counts) means resource contention
  between app and observability pods is a real risk if they share nodes.
* Need predictable EBS volume placement for retained storage volumes used by Prometheus/Loki/Grafana/
  Alertmanager/Kubecost.

## Options Considered

### Option 1: Single Shared Node Group for All Workloads

**Pros**

* Simpler Terraform configuration — one `eks_managed_node_groups` entry instead of two.
* Better bin-packing/utilization in a small cluster, since pods can land on any node.
* No taints/tolerations to manage.

**Cons**

* A chaos experiment that terminates an application-group node could just as easily terminate a node
  running Prometheus/Alertmanager, defeating the purpose of the experiment (the alerting system being
  validated could itself become unavailable).
* No control over which AZ observability's EBS-backed pods land in, risking PVC binding/scheduling
  failures if a pod reschedules to a node in a different AZ than its EBS volume.
* Resource contention between application and observability workloads is harder to reason about and
  isolate.

### Option 2: Separate, AZ-Pinned, Tainted Observability Node Group (Chosen)

**Pros**

* `observability` node group is pinned to a single AZ (`ap-southeast-1c`) and tainted
  (`workload=observability:NoSchedule`), guaranteeing only observability pods (with matching tolerations)
  land there and that their EBS volumes always attach within the correct AZ.
* The `application` node group remains untainted and is the sole target of the AWS FIS node-termination
  chaos experiment, so failure injection can never accidentally take down the monitoring/alerting stack
  needed to observe and alert on that very failure.
* Clear resource isolation: observability workloads cannot starve application workloads of CPU/memory,
  and vice versa.
* Matches a common production pattern of segregating platform/observability infrastructure from
  application compute.

**Cons**

* Slightly more Terraform configuration (two node groups instead of one, plus taints/tolerations on every
  observability workload's pod spec).
* Less efficient bin-packing in a small cluster — observability's dedicated AZ/node group can't be used
  for application overflow capacity.
* Requires every observability Helm chart/manifest to carry the correct toleration, or its pods will
  never schedule.

## Decision

The team chose to run observability workloads on a separate EKS managed node group
(`${cluster_name}-ng-observability`), pinned to AZ `ap-southeast-1c` and tainted with
`workload=observability:NoSchedule`, distinct from the untainted `application` node group used for the
retail-store microservices.

This decision was made primarily to make the chaos/failure-injection demo meaningful: AWS FIS targets only
the `application` node group, so the observability stack — including the alerts that are supposed to fire
in response to the induced failure — remains unaffected by the experiment. Pinning the node group to a
single AZ also removes a class of EBS-volume-AZ-mismatch scheduling failures for the stateful
observability components.

## Consequences

### Makes Easier

* Running realistic chaos/failure-injection demos without risking the observability stack that detects
  the failure.
* Reasoning about EBS volume AZ placement for Prometheus/Loki/Grafana/Alertmanager/Kubecost.
* Isolating resource contention between application and observability workloads.

### Rules Out

* Maximally efficient bin-packing of a small cluster across all workload types.
* Running observability pods without an explicit toleration for `workload=observability:NoSchedule`.
* Multi-AZ scheduling flexibility for observability pods (they are confined to `ap-southeast-1c`).
