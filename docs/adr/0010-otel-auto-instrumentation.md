# Architecture Decision Record (ADR)


# ADR 0010: Use OpenTelemetry Operator Injection for Distributed Tracing

## Status

Accepted

## Context

The observability stack (see [[0004-observability-stack]]) collects metrics and logs, but does not provide
distributed tracing — there is no way to follow a single request across the ui → catalog → carts →
checkout chain to see where latency or errors originate.

The five services use different runtimes: Java (carts, orders, ui), Node.js (checkout), and Go (catalog).
Instrumenting each service's source code individually would require code changes across four repositories
and five services, which is out of scope since this repo only contains Kubernetes manifests referencing
pre-built container images.

Key requirements:
* Tracing must be added without modifying application source code.
* Must cover all five services across the three runtime families (Java, Node.js, Go).
* Traces must flow through the existing ADOT collector pipeline to AWS X-Ray for storage and querying.
* Sampling must be set conservatively to limit cost and volume on a shared EKS cluster.

## Options Considered

### Option 1: Manual SDK Instrumentation in Each Service

**Pros**

* Full control over which spans are created and what attributes are attached.
* No dependency on an operator or mutating webhook.

**Cons**

* Requires source-code changes in all five service repositories — out of scope for a manifests-only repo.
* Different SDK per runtime (Java, Node.js, Go) multiplies the implementation effort.
* Changes would need to be reflected in new container image builds before they could be tested.

### Option 2: OpenTelemetry Operator Auto-Instrumentation (Chosen)

**Pros**

* Zero application code changes: the OTel Operator's mutating admission webhook injects instrumentation
  at pod creation time based on namespace/pod annotations.
* A single `Instrumentation` CR (`manifests/otel-instrumentation/instrumentation.yaml`) defines the
  shared configuration (exporter endpoint, propagators, sampler) applied to all services.
* Supports all three runtimes in use: Java and Node.js via init container, Go via eBPF sidecar.
* Integrates with the existing ADOT collector pipeline — traces are sent to the ADOT collector via OTLP
  HTTP and then exported to AWS X-Ray.

**Cons**

* Go auto-instrumentation uses an eBPF sidecar (not an init container), which requires the operator
  to be started with `--enable-go-instrumentation=true` and the `Instrumentation` CR to set
  `OTEL_GO_AUTO_TARGET_EXE` pointing to the service binary path. This is a separate code path and
  is not enabled by default.
* The mutating webhook's TLS certificate is auto-rotated, but if the operator pod restarts unexpectedly
  the `MutatingWebhookConfiguration` CA bundle can become stale — pods will fail admission until the
  operator is restarted to re-sync the bundle.
* Operator upgrades can silently break injection if feature gate names change between versions; the valid
  feature gates must be verified against the specific operator version in use.

### Option 3: Sidecar Proxy (Envoy/Linkerd)

**Pros**

* Handles tracing and load balancing as part of a full service mesh — no language-level SDK required.

**Cons**

* A service mesh is significant additional infrastructure for a project that does not need mesh features
  beyond tracing. The team has no existing expertise with Istio or Linkerd.
* Adds resource overhead (sidecar per pod) and operational complexity disproportionate to the goal of
  just getting distributed traces.

## Decision

The team chose OTel Operator auto-instrumentation via the `Instrumentation` CR pattern.

**Configuration details:**

* The OTel Operator is deployed via Helmfile with `--enable-go-instrumentation=true` in
  `helm/values/opentelemetry-operator.yaml` to enable the Go eBPF injection code path.
* The `Instrumentation` CR (`manifests/otel-instrumentation/instrumentation.yaml`) is configured with:
  * Exporter: `http://adot-collector.monitoring.svc.cluster.local:4318` (OTLP HTTP to ADOT)
  * Propagators: `tracecontext`, `baggage`
  * Sampler: `parentbased_traceidratio` at `0.1` (10% sampling)
  * Go section: `OTEL_GO_AUTO_TARGET_EXE=/app/main` (required for eBPF to locate the binary)
* Injection is triggered per service via pod annotations:
  * Java services (carts, orders, ui): `instrumentation.opentelemetry.io/inject-java: "monitoring/retail-store-instrumentation"`
  * Node.js service (checkout): `instrumentation.opentelemetry.io/inject-nodejs: "monitoring/retail-store-instrumentation"`
  * Go service (catalog): `instrumentation.opentelemetry.io/inject-go: "monitoring/retail-store-instrumentation"`
* Traces flow: instrumented pods → ADOT collector → AWS X-Ray, queryable via the Grafana X-Ray datasource.

## Consequences

### Makes Easier

* Adding or removing tracing from a service is a one-line annotation change in the deployment manifest.
* All five services share a single sampler and exporter configuration in one CR.
* Traces appear in AWS X-Ray and the Grafana traces dashboard without any application code changes.

### Rules Out

* Per-service custom span attributes or fine-grained instrumentation without modifying application source.
* Using a Go binary path other than `/app/main` for new Go services without updating the `Instrumentation`
  CR's `OTEL_GO_AUTO_TARGET_EXE` value (or overriding it per-pod via an annotation).
