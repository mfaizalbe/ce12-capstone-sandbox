# A | DEMO

# 1. Healthcheck of system

## Useful URL

- [Store: http://grp5.sctp-sandbox.com/](http://grp5.sctp-sandbox.com/)

- [Grafana: http://grp5-grafana.sctp-sandbox.com/](http://grp5-grafana.sctp-sandbox.com/)

### Check Demo dashboard

```bash
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

- [Kubecost: http://grp5-kubecost.sctp-sandbox.com/](http://grp5-kubecost.sctp-sandbox.com/)

- [ArgoCD: http://grp5-argocd.sctp-sandbox.com/](http://grp5-argocd.sctp-sandbox.com/)

### To see if ArgoCD is working

```bash
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode
```

- [Prometheus: http://grp5-prometheus.sctp-sandbox.com/](http://grp5-prometheus.sctp-sandbox.com/)

# 2. Connect to AWS cluster

aws eks --region ap-southeast-1 update-kubeconfig --name retail-store-grp5

# 3. To see that all pods are healthy

kubectl get all -A

# 4. Launch DevOps Agent

# 5. Show list of dashboards

# 6. Show Demo Dashboard

## Click in to one dashboard to see baseline of logs/ metrics etc. before node failure

## See Alerts section before node failure

# 7. Trigger node failure

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION="ap-southeast-1"
export FIS_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/retail-store-grp5-fis-role"
export CLUSTER_NAME="retail-store-grp5"
export NODEGROUP_NAME=$(aws eks list-nodegroups --region "$AWS_REGION" --cluster-name "$CLUSTER_NAME" --query "nodegroups[?starts_with(@, '${CLUSTER_NAME}-ng-application')]" --output text)
export NODEGROUP_ARN=$(aws eks describe-nodegroup --region "$AWS_REGION" --cluster-name "$CLUSTER_NAME" --nodegroup-name "$NODEGROUP_NAME" --query 'nodegroup.nodegroupArn' --output text)
```

Create the experiment template (this only defines the experiment, it does not run anything yet):

```bash
export NODE_EXP_ID=$(aws fis create-experiment-template --region "$AWS_REGION" --cli-input-json '{"description":"NodeDeletion","targets":{"target-nodegroup":{"resourceType":"aws:eks:nodegroup","resourceArns":["'$NODEGROUP_ARN'"],"selectionMode":"ALL"}},"actions":{"nodedeletion":{"actionId":"aws:eks:terminate-nodegroup-instances","parameters":{"instanceTerminationPercentage":"67"},"targets":{"Nodegroups":"target-nodegroup"}}},"stopConditions":[{"source":"none"}],"roleArn":"'$FIS_ROLE_ARN'","tags":{"ExperimentSuffix":"DEMO"}}' --output json | jq -r '.experimentTemplate.id')
```

Run it (this actually terminates instances — only do this on a cluster you're OK disrupting):

```bash
aws fis start-experiment --region "$AWS_REGION" --experiment-template-id "$NODE_EXP_ID" --output json
```

# 8. Show Demo Dashboard

## See Alerts section after triggering node failure

# 9. View DevOps Agent

## Ask DevOps Agent what happened

# 10. Wait for everything to recover (Self-healing, self-orchestration)

# 11. Update replica number of UI pods in manifests/ui/deployment.yaml from 1 to 2

# 12. git commit

git add .
git commit -m "Updated UI pods replica number"
git push

# 13. Go into ArgoCD browser to check

# 14. kubectl get deployment -n ui

## Will show changed replica and syncing

# B | SLIDES & ARCHITECTURE

## ARCHITECTURE

# 1. Webhook alerts to Discord

# 2. Linking up DevOps Agent to our project

# 3. Application architecture (EKS, UI, database, microservices, external DNS (Route 53) controller, load balancer controller)

# 4. Logs management architecture

# 5. Metrics (including Kubecost)

# 6. Traces

# 7. ArgoCD

# 8. Demo -- Fault injection and node generator
