# Architecture Decision Record (ADR)


# ADR 0001: Use Amazon EKS as the Compute Platform

## (i) Status

Accepted

## (ii) Context (Constraints that shaped the decision (team size, traffic, tooling))

The Retail Store SRE capstone project requires a cloud-native platform capable of hosting containerised services while supporting observability and operational best practices. The project team consists of five members working within a one-month timeframe.

Key constraints and requirements include:

* Multiple containerised application components.
* Need to demonstrate Site Reliability Engineering (SRE) practices.
* Integration with monitoring and observability tools such as Grafana.
* Ability to manage deployments consistently across environments.
* Limited development time requiring the use of managed cloud services.
* Expected traffic is moderate, with emphasis on reliability and operational visibility rather than large-scale production workloads.

## (iii) Options Considered (At least two, each with pros and cons)

### Option 1: Amazon EC2 with Docker Containers

**Pros**

* Simpler architecture.
* Lower learning curve.
* Greater control over the underlying infrastructure.
* Potentially lower cost for small workloads.

**Cons**

* Manual container orchestration.
* More operational overhead for deployment and scaling.
* Limited support for Kubernetes-native tooling.
* Less representative of modern cloud-native SRE practices.

### Option 2: Amazon EKS (Elastic Kubernetes Service) with Helm

**Pros**

* Managed Kubernetes control plane.
* Supports automated scaling and self-healing capabilities.
* Helm simplifies application deployment and configuration management.
* Integrates well with observability tools such as Grafana.
* Aligns with industry-standard cloud-native and SRE practices.
* Provides a realistic platform for learning Kubernetes operations.

**Cons**

* Higher complexity than EC2-based deployments.
* Steeper learning curve for team members unfamiliar with Kubernetes.
* Higher infrastructure costs.
* Additional configuration required for cluster management.

## (iv) Decision (What was chosen and why)

The team chose Amazon EKS as the compute platform and Helm as the deployment management tool.

This decision was made because the project focuses on Site Reliability Engineering practices and requires a platform that demonstrates modern cloud-native operations. EKS provides managed Kubernetes capabilities while reducing the burden of maintaining the Kubernetes control plane. Helm enables repeatable and consistent application deployments, and the platform integrates effectively with Grafana-based monitoring and observability solutions.

Although EKS introduces additional complexity, it offers valuable experience with technologies commonly used in production environments and better supports the project's learning objectives.

## (v) Consequences (What this makes easier, and what it rules out)

### Makes Easier

* Deployment and management of containerised workloads.
* Standardised application releases through Helm charts.
* Integration with monitoring and observability platforms such as Grafana.
* Demonstration of Kubernetes-based SRE practices.
* Future scaling and expansion of services.
* Automated workload recovery through Kubernetes mechanisms.

### Rules Out

* Simpler VM-based deployment architectures.
* Minimal-infrastructure operational models.
* Teams with no Kubernetes knowledge being immediately productive.
* Lowest-cost deployment option for small workloads.
* Direct management of applications outside the Kubernetes ecosystem.

