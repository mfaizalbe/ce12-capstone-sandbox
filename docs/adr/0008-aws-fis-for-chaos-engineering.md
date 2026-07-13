# Architecture Decision Record (ADR)


# ADR 0008: Use AWS Fault Injection Service for Chaos/Failure-Injection Demos

## Status

Accepted

## Context

As an SRE capstone, the team wants to demonstrate that the alerting stack actually detects real
infrastructure failures, not just that PromQL rules are syntactically correct. This requires deliberately
injecting a failure (e.g. terminating a node) and confirming that the expected alerts
(`NodeNotReady`, `RetailStorePodsPending` in `manifests/alerts/prometheusrule.yaml`) fire.

Key constraints and requirements include:

* The cluster runs on AWS EKS, so the failure-injection mechanism ideally integrates natively with AWS
  infrastructure (EC2/Auto Scaling Groups/EKS node groups) rather than requiring in-cluster agents.
* The experiment must target only the `application` node group, not the `observability` node group, so
  the alerting/monitoring stack survives to observe and report on the induced failure (see
  [[0005-dedicated-observability-node-group]]).
* Limited time to learn and configure a chaos engineering tool, favoring something with direct IAM-based
  AWS integration over installing and operating an additional in-cluster chaos framework.
* Experiments should be safely scoped (IAM role limited to node-termination actions) to avoid accidental
  blast radius beyond the intended demo.

## Options Considered

### Option 1: In-Cluster Chaos Tooling (e.g. Chaos Mesh, LitmusChaos)

**Pros**

* Kubernetes-native: failures are defined and injected as CRDs/manifests, consistent with the rest of the
  app's deployment model (Kustomize).
* Rich library of failure types beyond node termination (network latency, pod kill, I/O faults, etc.).

**Cons**

* Requires installing and operating yet another in-cluster controller and its CRDs, adding to the
  Helmfile/CRD-ownership surface area already being managed for the platform stack.
* Most chaos frameworks' "node failure" simulations operate at the pod/kubelet level (e.g. killing the
  kubelet process) rather than actually terminating the underlying EC2 instance, making them a less
  realistic test of the `NodeNotReady` alert path than an actual instance termination.
* Additional learning curve and maintenance burden for a capability used only for a one-off demo.

### Option 2: Manual `kubectl`/AWS CLI Commands

**Pros**

* No new tooling — just `aws ec2 terminate-instances` or `kubectl drain`/cordon run ad hoc.
* Fastest to get started with no setup.

**Cons**

* Not repeatable or reviewable as code; no audit trail of what was injected and when.
* Manual AWS CLI termination requires broad EC2 permissions on whoever runs it, rather than a scoped,
  purpose-built IAM role.
* Doesn't demonstrate a structured chaos engineering practice, only an ad hoc one-off action.

### Option 3: AWS Fault Injection Service (FIS) (Chosen)

**Pros**

* Native AWS service for fault injection against real AWS resources (EC2 instances), so terminating
  nodes via FIS (67% of the application node group) is an authentic test of the actual failure mode
  (`NodeNotReady`) rather than a simulated one.
* Experiment templates and the dedicated IAM role (`${cluster_name}-fis-role`, scoped to node-termination
  actions via `terraform/iam.tf`) make the blast radius explicit and auditable as Terraform-managed code.
* No additional in-cluster controller or CRDs required — keeps the cluster's CRD-ownership model
  (Helmfile owns controller CRDs, Kustomize owns instances) unchanged.
* Experiment templates can be scoped to target only the `application` node group, preserving the
  observability stack for alert verification.

**Cons**

* AWS-specific; the experiment design would not be portable to a non-AWS Kubernetes cluster.
* Less expressive than dedicated chaos frameworks for failure types beyond infrastructure-level faults
  (no built-in network latency/packet loss/pod-level fault injection).
* Requires understanding FIS's experiment template JSON structure, a tool-specific learning curve in
  itself.

## Decision

The team chose AWS FIS, with a dedicated IAM role scoped to node-termination permissions
(`terraform/iam.tf`), to run the node-failure chaos demo against the `application` node group.

This decision was made because FIS terminates real EC2 instances (67% of the application node group),
providing an authentic trigger for the `NodeNotReady` and `RetailStorePodsPending` alerts rather than a
simulated kubelet-level fault, and because
it avoids installing another in-cluster controller purely for a single demo scenario. Scoping the
experiment's IAM role to node-termination actions, and targeting only the `application` node group, keeps
the blast radius explicit and prevents the demo from disrupting the observability stack needed to verify
it.

## Consequences

### Makes Easier

* Producing an authentic, auditable demonstration that alerting rules detect real node failures.
* Reviewing the experiment's permissions and scope as Terraform-managed IAM policy, rather than ad hoc CLI
  access.
* Keeping the chaos-testing capability decoupled from the in-cluster CRD-ownership model.

### Rules Out

* Portability of the chaos demo to a non-AWS Kubernetes environment.
* Simulating failure types beyond what FIS's EC2 actions support (e.g. network-level faults) without
  adopting an additional tool.
* Running the experiment against the `observability` node group without redesigning the experiment
  template and accepting the risk of losing alert visibility during the test.
