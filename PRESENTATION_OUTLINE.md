# A. Demo

## 1. Health Check the System

### Useful URLs

- **Store:** http://grp5.sctp-sandbox.com/
- **Grafana:** http://grp5-grafana.sctp-sandbox.com/
- **Kubecost:** http://grp5-kubecost.sctp-sandbox.com/
- **ArgoCD:** http://grp5-argocd.sctp-sandbox.com/
- **Prometheus:** http://grp5-prometheus.sctp-sandbox.com/

### Grafana Login

Retrieve the Grafana admin password:

```bash
kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode
```

### ArgoCD Login

Retrieve the ArgoCD admin password:

```bash
kubectl get secret -n argocd argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode
```

---

## 2. Connect to the AWS Cluster

```bash
aws eks --region ap-southeast-1 update-kubeconfig --name retail-store-grp5
```

---

## 3. Verify All Pods Are Healthy

```bash
kubectl get all -A
```

---

## 4. Launch DevOps Agent

---

## 5. Show List of Dashboards

---

## 6. Show Demo Dashboard

### Before Node Failure

- View dashboard metrics and logs
- Review the **Alerts** section

---

## 7. Trigger Node Failure

### Configure Environment Variables

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

export AWS_REGION="ap-southeast-1"

export FIS_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/retail-store-grp5-fis-role"

export CLUSTER_NAME="retail-store-grp5"

export NODEGROUP_NAME=$(aws eks list-nodegroups \
  --region "$AWS_REGION" \
  --cluster-name "$CLUSTER_NAME" \
  --query "nodegroups[?starts_with(@, '${CLUSTER_NAME}-ng-application')]" \
  --output text)

export NODEGROUP_ARN=$(aws eks describe-nodegroup \
  --region "$AWS_REGION" \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODEGROUP_NAME" \
  --query 'nodegroup.nodegroupArn' \
  --output text)
```

### Create the FIS Experiment Template

This only defines the experiment. It does **not** run it.

```bash
export NODE_EXP_ID=$(aws fis create-experiment-template \
  --region "$AWS_REGION" \
  --cli-input-json '{
    "description":"NodeDeletion",
    "targets":{
      "target-nodegroup":{
        "resourceType":"aws:eks:nodegroup",
        "resourceArns":["'"$NODEGROUP_ARN"'"],
        "selectionMode":"ALL"
      }
    },
    "actions":{
      "nodedeletion":{
        "actionId":"aws:eks:terminate-nodegroup-instances",
        "parameters":{
          "instanceTerminationPercentage":"67"
        },
        "targets":{
          "Nodegroups":"target-nodegroup"
        }
      }
    },
    "stopConditions":[{"source":"none"}],
    "roleArn":"'"$FIS_ROLE_ARN"'",
    "tags":{"ExperimentSuffix":"DEMO"}
  }' \
  --output json | jq -r '.experimentTemplate.id')
```

### Start the Experiment

> **Warning:** This terminates worker nodes. Only run this on a cluster you are prepared to disrupt.

```bash
aws fis start-experiment \
  --region "$AWS_REGION" \
  --experiment-template-id "$NODE_EXP_ID" \
  --output json
```

---

## 8. Return to the Demo Dashboard

### After Node Failure

- Observe dashboard changes
- Review triggered alerts

---

## 9. View DevOps Agent

Ask the DevOps Agent:

- What happened?
- What caused the incident?
- What actions were taken?

---

## 10. Wait for Recovery

Observe:

- Self-healing
- Self-orchestration
- Workloads returning to a healthy state

---

## 11. Update UI Replicas

Modify:

```
manifests/ui/deployment.yaml
```

Change:

```yaml
replicas: 1
```

to

```yaml
replicas: 2
```

---

## 12. Commit and Push Changes

```bash
git add .

git commit -m "Update UI replica count"

git push
```

---

## 13. Verify ArgoCD Sync

Open the ArgoCD UI and confirm the application synchronizes successfully.

---

## 14. Verify Deployment

```bash
kubectl get deployment -n ui
```

Confirm the updated replica count has been applied.

---

# B. Slides & Architecture

## Architecture

### 1. Application Architecture

Topics:

- Amazon EKS
- UI
- Database
- Microservices
- Route 53 ExternalDNS Controller
- AWS Load Balancer Controller
- API Gateway

---

### 2. Logs Management Architecture

---

### 3. Metrics

Including:

- Prometheus
- Grafana
- Kubecost

---

### 4. Traces

---

## Diagrams

Export the following Draw.io diagrams as PNGs and insert them into the presentation:

- Overview
- Application Microservices
- API Gateway
- Metrics / Logs / Services

---

# Presentation Flow

## Arista

### Introduction

- Group Members
- SRE + DevOps Project Overview

### Architecture Overview

- Overall Architecture (Indy's diagram)

---

## Sze Kong

### Application Architecture

- Application diagram

### API Gateway

- API Gateway diagram

---

## Indy

### Observability

- Metrics
- Logs
- Traces
- EBS

---

## CD Pipeline

Explain the deployment flow:

```
GitHub
    ↓
CI/CD
    ↓
AWS
    ↓
Amazon EKS
```

---

## Gina

### Dashboards Overview

Introduce the four dashboards.

### Node Failure Demo

---

## Faizal

### ArgoCD Demo

### Limitations & Future Improvements

### Key Takeaways

---

## Q&A

---

# Demo Checklist

- [x] Discord webhook alerts
- [x] DevOps Agent integration
- [x] ArgoCD deployment
- [x] Fault injection (AWS FIS)
- [x] Node failure demonstration
