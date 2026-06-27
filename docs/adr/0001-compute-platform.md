# Architecture Decision Record (ADR)


# ADR 0001: Compute Platform (Amazon EKS)

## (i) Status

Accepted

## (ii) Context (Constraints that shaped the decision (team size, traffic, tooling))

The Retail Store SRE capstone project is deployed on AWS and uses Kubernetes-based infrastructure to support multiple containerised microservices. The project team consists of five members working within a one-month timeframe.

Key constraints and requirements include:
- Running multiple containerised services
- Demonstrating Site Reliability Engineering (SRE) practices
- Supporting observability and monitoring tools such as Grafana
- Using a managed platform to reduce operational overhead
- Aligning with modern cloud-native architecture practices

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

The team chose Amazon EKS as the compute platform.

EKS provides a managed Kubernetes environment that supports containerised workloads while reducing the operational burden of managing a Kubernetes control plane. The platform aligns with the project's SRE objectives by enabling high availability, automated recovery, and scalability. It also supports integration with the team's deployment and monitoring tools.

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

