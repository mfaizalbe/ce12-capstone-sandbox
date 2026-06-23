# Architecture Decision Record (ADR)


# ADR 0002: Use Gateway API Instead of Classic Ingress

## Status

Accepted

## Context

The retail-store UI service needs to be exposed to the internet through an AWS Application Load
Balancer. The team needed to choose between the classic Kubernetes `Ingress` resource (the long-standing,
widely-documented standard) and the newer Gateway API (`Gateway`, `HTTPRoute`, `GatewayClass`), both of
which are supported by the AWS Load Balancer Controller.

Key constraints and requirements include:

* A single externally-reachable hostname (`grp5.sctp-sandbox.com`) routed to the `ui` service.
* The AWS Load Balancer Controller (installed via Helmfile) must provision and manage the ALB.
* Desire to demonstrate current cloud-native practices rather than legacy patterns, since this is a
  learning-focused SRE capstone.
* Limited one-month timeframe, so tooling familiarity and documentation availability matter.

## Options Considered

### Option 1: Classic Ingress

**Pros**

* Mature, stable API present in Kubernetes since early versions.
* Most tutorials, Stack Overflow answers, and AWS Load Balancer Controller examples default to it.
* Single resource type (`Ingress`) is simpler to reason about for a single-route use case.

**Cons**

* `Ingress` annotations are vendor-specific and inconsistent across controllers, making behaviour
  implicit rather than explicit.
* Being phased out as the long-term Kubernetes networking standard in favour of Gateway API.
* Less expressive routing model; harder to extend (e.g. per-namespace route delegation, multiple
  protocols) without controller-specific extensions.

### Option 2: Gateway API (Gateway + HTTPRoute + GatewayClass)

**Pros**

* Successor API to Ingress, designed by SIG-Network to be the long-term standard.
* Clear separation of concerns: infrastructure operators own the `Gateway` (and
  `LoadBalancerConfiguration`), while application teams own `HTTPRoute` — a better fit for
  multi-namespace, multi-team setups.
* Explicit, typed configuration (listeners, route matches, backend refs) instead of opaque annotations.
* AWS Load Balancer Controller's Gateway API support (`aws-alb` GatewayClass) is actively developed and
  maps cleanly onto ALB target groups.
* Demonstrates current/emerging cloud-native practice, aligning with the project's learning objectives.

**Cons**

* Requires installing additional CRDs (`Gateway`, `HTTPRoute`, `GatewayClass`,
  `LoadBalancerConfiguration`, `TargetGroupBinding`) before any routes can be applied — adds a dependency
  the team must sequence correctly (Helmfile presync hook, per `docs/installation.md`).
* Newer API with fewer examples and less community troubleshooting content than Ingress.
* Higher conceptual overhead for a single-service, single-hostname use case where Ingress would have been
  sufficient on its own.

## Decision

The team chose Gateway API (`manifests/ui/gateway.yaml`, `httproute.yaml`, `gatewayclass.yaml`,
`loadbalancerconfig.yaml`, `targetgrpconf.yaml`) over classic Ingress for exposing the UI service.

This decision was made to align with the direction Kubernetes networking is heading and to give the team
hands-on experience with the API that is expected to eventually supersede Ingress. The explicit
separation between `Gateway` (infrastructure) and `HTTPRoute` (application) also mirrors how the rest of
the repo separates concerns (Terraform/Helmfile own infrastructure and CRDs, Kustomize owns application
instances), making the choice consistent with the project's broader architectural pattern.

## Consequences

### Makes Easier

* Clean separation between infrastructure-owned (`Gateway`) and application-owned (`HTTPRoute`) routing
  configuration.
* Future addition of more routes/hostnames/services without redesigning the ingress layer.
* Demonstrating familiarity with current Kubernetes networking standards.

### Rules Out

* Relying on widely-available Ingress-specific tutorials and annotation-based configuration.
* Skipping the CRD-installation step — Gateway API resources cannot be applied before the ALB
  controller's Gateway CRDs are present.
* Compatibility with tooling that only understands classic Ingress.
