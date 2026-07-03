# A. Demonstration (Demo)

## 1. Connect to the AWS Cluster

```bash
aws eks --region ap-southeast-1 update-kubeconfig --name retail-store-grp5
```

---

## 2. Verify All Pods Are Healthy

```bash
kubectl get all -A
```

---

## 3. Health Check the System

Load all the URLs.
Check Demo Dashboard and ArgoCD, and ensure that they are working.

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

## 4. Launch DevOps Agent to Load in Background First

---

## 5. Show Retail Store Application

---

## 6. Show Kubecosts

---

## 7. Grafana Dashboards Overview

Show list of the four main Dashboards.

---

## 8. Show Demo Dashboard

### Before Node Failure

- Enter one dashboard to view dashboard metrics and logs
- See the **Alerts** section before node failure

---

## 9. Trigger Partial Node Failure with Fault Injection Service (AWS FIS)

### (i) Configure Environment Variables

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

#Note: Amazon EKS --> Clusters --> retail-store-grp5 --> Node groups --> Group name (application)

export NODEGROUP_ARN=$(aws eks describe-nodegroup \
  --region "$AWS_REGION" \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODEGROUP_NAME" \
  --query 'nodegroup.nodegroupArn' \
  --output text)
```

### (ii) Create the FIS Experiment Template

This only defines the experiment. It does **not** run anything yet.

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

### (iii) Start the Experiment

> **Warning:** This terminates worker nodes and instances. Only run this on a cluster you are prepared to disrupt.

```bash
aws fis start-experiment \
  --region "$AWS_REGION" \
  --experiment-template-id "$NODE_EXP_ID" \
  --output json
```

---

## 10. Return to the Demo Dashboard

### After Node Failure

- Observe dashboard changes
- Review triggered alerts

---

## 11. View DevOps Agent

Ask the DevOps Agent:

- What happened in a particular cluster (indicate cluster e.g., retail-store-grp5, and region e.g., ap-southeast-1)?
- What caused the incident?
- What actions were taken?

---

## 12. Wait for Recovery

Observe:

- Self-healing
- Self-orchestration
- Workloads returning to a healthy state

---

## 13. ArgoCD Demo (Update UI Replicas)

Update replica number of UI pods (under specs) in manifests/ui/deployment.yaml from 1 to 2

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

## 14. Commit and Push Changes

```bash
git add .

git commit -m "Update UI pods replica count"

git push
```

---

## 15. Verify ArgoCD Sync

Open the ArgoCD UI browser and confirm the application synchronises successfully.

---

## 16. Verify Deployment

Confirm the updated replica count has been applied.

```bash
kubectl get deployment -n ui
```

---

# B. Slides & Architecture

## Architecture

### 1. Application Architecture

Look at diagrams from slides Overview, then draw.io tabs 1 (Application Microservices), 3 (API Gateway), 5 (revised Metrics, Logs, Services) [To download from draw.io as png and insert into slides]

Topics:

- Amazon EKS --> draw.io Tabs 1, 3
- UI --> draw.io Tabs 1, 3
- Database --> draw.io Tabs 1, 3
- Microservices --> draw.io Tabs 1, 3 
- Route 53 ExternalDNS Controller --> draw.io Tabs 1, 3
- AWS Load Balancer Controller --> draw.io Tabs 1, 3
- API Gateway --> draw.io Tabs 1, 3

---

### 2. Logs Management Architecture

--> draw.io Tab 5

---

### 3. Metrics

Including:

- Prometheus
- Grafana
- Kubecost

--> draw.io Tab 5

---

### 4. Traces

--> draw.io Tab 5

---

## Diagrams

Export the following Draw.io diagrams as PNGs and insert them into the presentation:

- Overview
- Application Microservices (draw.io Tab 1)
- API Gateway (draw.io Tab 3)
- Metrics / Logs / Services (draw.io Tab 5)

---

# C. Presentation Flow

## Arista

### 1) Introduction

- (i) Group Members
- (ii) SRE + DevOps Project Overview

### 2) Architectures

#### (i) Architecture Overview

- Overall Architecture (Indy's diagram)

---

## Sze Kong

#### (ii) Application Architecture

- Application diagram

#### (iii) API Gateway Architecture

- API Gateway diagram

---

## Indy

#### (iv) Observability Architecture

- Metrics
- Logs
- Traces
- EBS

---

### 3) CD Process/ Pipeline

Explain the deployment flow:

```
 GitHub
    ↓
   CD
    ↓
   AWS
    ↓
Amazon EKS
```

---

## Gina

### 4) Retail Store Application

### 5) Kubecosts

### 6) Grafana Dashboards Overview

(i) Introduce the four dashboards.
(ii) View alerts section.

### 7) Partial Node Failure Simulation with Fault Injection Service (AWS FIS)

(i) Trigger node failure
(ii) View dashboard alerts section
(iii) View DevOps Agent and ask the DevOps Agent:
 
- What happened in a particular cluster (indicate cluster)?
- What caused the incident?
- What actions were taken?

(These will take some time to load. Proceed back to dashboard alerts first after entering prompts.)


(iv) Return to dashboard alerts section and wait for recovery

Observe:

- Self-healing
- Self-orchestration
- Workloads returning to a healthy state

### 8) Webhooked Alerts to Discord

### 9) DevOps Agent Integration

(Return back to DevOps Agent and see if prompts have completed loading.)

---

## Faizal

### 10) ArgoCD Demo

### 11) Limitations & Future Improvements

### 12) Key Takeaways

---

## All

### 13) Q&A

---

# D. Demonstration Checklist

- [x] Retail store application
- [x] Kubecosts
- [x] Grafana Dashboards Overview
- [x] Partial Node Failure Simulation with Fault Injection Service (AWS FIS)
- [x] Discord Webhooked Alerts
- [x] DevOps Agent Integration
- [x] ArgoCD deployment
