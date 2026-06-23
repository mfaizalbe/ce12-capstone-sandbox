# Architecture Decision Record (ADR)


# ADR 0006: Use S3 Remote State with Native S3 Locking for Terraform

## Status

Accepted

## Context

Five team members need to run Terraform against the same EKS cluster and supporting infrastructure
(`terraform/`) without corrupting state or applying conflicting changes concurrently. The team needed to
choose how and where to store Terraform state and how to handle locking during concurrent applies.

Key constraints and requirements include:

* Multiple contributors apply Terraform from their own laptops; state cannot live only on a single
  person's machine (local state) without risking drift, loss, or conflicting applies.
* The project already uses AWS as its cloud provider, so an AWS-native backend avoids introducing a new
  external dependency.
* Limited time and team size means the simplest backend that still provides safe concurrent access is
  preferable to a more elaborate setup.

## Options Considered

### Option 1: Local State (Committed or Uncommitted)

**Pros**

* Zero setup — no backend configuration needed.
* No additional AWS resources (S3 bucket) required.

**Cons**

* No locking at all; two team members applying simultaneously can corrupt state or apply conflicting
  changes.
* State either lives on one person's machine (single point of failure, not shareable) or gets committed
  to git (risk of leaking secrets/resource IDs, and merge conflicts on a binary-ish JSON file).
* Not viable for a five-person team working concurrently.

### Option 2: S3 Backend + DynamoDB Table for Locking (the traditional pattern)

**Pros**

* Long-established, widely documented pattern; most Terraform tutorials and examples use this exact
  combination.
* DynamoDB locking is battle-tested.

**Cons**

* Requires provisioning and maintaining an additional AWS resource (a DynamoDB table) purely for locking,
  with its own IAM permissions to manage.
* More moving parts than necessary now that S3 supports native locking directly.

### Option 3: S3 Backend with Native S3 Locking (`use_lockfile`) (Chosen)

**Pros**

* Single AWS resource (the S3 bucket `capstone-project-group5`) serves as both state storage and lock
  storage — no separate DynamoDB table to provision, configure, or pay for.
* Simpler `terraform/providers.tf` backend block (`bucket`, `key`, `use_lockfile = true`) with fewer
  moving parts than the S3+DynamoDB pattern.
* Shared, durable state accessible to all five team members, with automatic locking during `apply`/
  `destroy` to prevent concurrent conflicting operations.

**Cons**

* Native S3 locking is a newer Terraform/AWS provider feature with less community track record than the
  S3+DynamoDB pattern; fewer existing examples to reference if something goes wrong.
* Still depends on correct AWS credentials/permissions being configured per-contributor to read/write the
  state bucket.

## Decision

The team chose an S3 backend (bucket `capstone-project-group5`, key `eks/default/terraform.tfstate`) with
native S3 locking (`use_lockfile = true`) rather than local state or the traditional S3+DynamoDB locking
pattern.

This decision was made because native S3 locking provides the same safety guarantee (preventing concurrent
conflicting applies across the five-person team) as the S3+DynamoDB pattern while requiring one fewer AWS
resource to provision and maintain, which fit the project's preference for minimizing infrastructure
surface area within a one-month timeframe.

## Consequences

### Makes Easier

* Safe concurrent Terraform usage across five contributors without manual coordination.
* Onboarding new contributors — only an S3 bucket and AWS credentials are needed, no DynamoDB table setup.
* Keeping the Terraform backend configuration minimal and easy to audit.

### Rules Out

* Local-only or git-committed state.
* Reliance on DynamoDB-based locking tooling or any documentation/examples specific to that pattern.
* Using a Terraform version/AWS provider combination that predates native S3 locking support.
