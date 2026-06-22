# SCTP CE12 Group 5 Capstone Project

Sandbox repository for the CE12 DevOps Capstone project to experiment with application code, infrastructure, CI/CD, monitoring, and security.

## The Team

- SK
- Arista
- Gina
- Indy
- ƒαιzαℓ.

## Project Structure

```text
ce12-capstone-sandbox/
├── docs/
├── grafana/
│   ├── connections
│   └── dashboards
├── helm/
│   ├── crds/
│   ├── values/
│   ├── helmfile.yaml.gotmpl
│   └── retained-storage.yaml
├── manifests/
│   ├── adot/
│   ├── alerts/
│   ├── carts/
│   ├── catalog/
│   ├── checkout/
│   ├── fluentbit/
│   ├── grafana/
│   ├── kubecost/
│   ├── load-gen/
│   ├── orders/
│   ├── ui/
│   └── kustomization.yaml
├── terraform/
│   ├── eks.tf
│   ├── iam.tf
│   ├── main.tf
│   ├── providers.tf
│   ├── variables.tf
│   └── vpc.tf
├── .gitignore
└── README.md
```

## Setup

Create retained volumes

```bash
aws ec2 create-volume --region ap-southeast-1 --availability-zone ap-southeast-1c --size 20 --volume-type gp3 --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=retail-store-grp5-prometheus-retained}]'
aws ec2 create-volume --region ap-southeast-1 --availability-zone ap-southeast-1c --size 20 --volume-type gp3 --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=retail-store-grp5-loki-retained}]'
aws ec2 create-volume --region ap-southeast-1 --availability-zone ap-southeast-1c --size 10 --volume-type gp3 --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=retail-store-grp5-grafana-retained}]'
aws ec2 create-volume --region ap-southeast-1 --availability-zone ap-southeast-1c --size 10 --volume-type gp3 --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=retail-store-grp5-alertmanager-retained}]'
aws ec2 create-volume --region ap-southeast-1 --availability-zone ap-southeast-1c --size 20 --volume-type gp3 --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=retail-store-grp5-kubecost-retained}]'
```

create s3 for loki
create s3 for backend

## Startup

### Provision VPC, EKS Cluster, Helm Installation of Services

```bash
terraform -chdir=terraform init
terraform -chdir=terraform apply
```

### Helm Chart installation

```bash
aws eks --region ap-southeast-1 update-kubeconfig --name retail-store-grp5
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
# export AWS_ACCOUNT_ID=255945442255  # use this if the above didn't work
export VPC_ID=$(aws eks describe-cluster --name retail-store-grp5 --region ap-southeast-1 --query 'cluster.resourcesVpcConfig.vpcId' --output text)
export PROMETHEUS_EBS_VOLUME_ID=vol-0fd603b3e2cf7ca08
export PROMETHEUS_EBS_AZ=ap-southeast-1c
export LOKI_EBS_VOLUME_ID=vol-03735bc2949c6340d
export LOKI_EBS_AZ=ap-southeast-1c
export GRAFANA_EBS_VOLUME_ID=vol-051c46eca0f1598f7
export GRAFANA_EBS_AZ=ap-southeast-1c
export ALERTMANAGER_EBS_VOLUME_ID=vol-0604f19be368a27a1
export ALERTMANAGER_EBS_AZ=ap-southeast-1c
export KUBECOST_EBS_VOLUME_ID=vol-0a8125c27398ef004
export KUBECOST_EBS_AZ=ap-southeast-1c
helmfile -f helm/helmfile.yaml.gotmpl lint #optional
helmfile -f helm/helmfile.yaml.gotmpl sync
```

Validation:

```bash
helmfile -f helm/helmfile.yaml.gotmpl list
kubectl get pods -n kube-system  # shows aws-load-balancer-controller healthy.
kubectl get pods -n external-dns # shows external-dns healthy.
kubectl get pods -n monitoring   # shows prometheus/grafana healthy.

kubectl get pv retained-grafana-pv retained-prometheus-tsdb-pv retained-loki-data-pv retained-alertmanager-data-pv retained-kubecost-local-store-pv
kubectl get pvc -n monitoring
kubectl get pvc -n kubecost
kubectl get pods -n monitoring
kubectl get pods -n kubecost

kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].spec.volumes}'
kubectl get pod -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].spec.volumes}'
kubectl get pod -n monitoring -l app.kubernetes.io/name=loki -o jsonpath='{.items[0].spec.volumes}'
```

### Start Application with Kustomize

```bash
aws eks --region ap-southeast-1 update-kubeconfig --name retail-store-grp5
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=ap-southeast-1
export EKS_CLUSTER_NAME=retail-store-grp5
kubectl kustomize manifests | envsubst '${AWS_ACCOUNT_ID} ${EKS_CLUSTER_NAME} ${AWS_REGION}' | kubectl apply -f -
```

Validation

```bash
kubectl get all -A
```

## Shutdown

```bash
kubectl delete -k manifests
helmfile -f helm/helmfile.yaml.gotmpl destroy
terraform -chdir=terraform destroy
```

## Useful URL

- [Store: http://grp5.sctp-sandbox.com/](http://grp5.sctp-sandbox.com/)
- [Grafana: http://grp5-grafana.sctp-sandbox.com/](http://grp5-grafana.sctp-sandbox.com/)
- [Kubecost: http://grp5-kubecost.sctp-sandbox.com/](http://grp5-grafana.sctp-sandbox.com/)

## Useful commands

### Get Grafana Admin Password

```bash
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

## DEMO

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export FIS_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/retail-store-grp5-fis-role"
```

```bash
export NODE_EXP_ID=$(aws fis create-experiment-template --cli-input-json '{"description":"NodeDeletion","targets":{"retail-store-grp5-ng-application":{"resourceType":"aws:eks:nodegroup","resourceTags":{"eksctl.cluster.k8s.io/v1alpha1/cluster-name":"retail-store-grp5"},"selectionMode":"COUNT(1)"}},"actions":{"nodedeletion":{"actionId":"aws:eks:terminate-nodegroup-instances","parameters":{"instanceTerminationPercentage":"80"},"targets":{"Nodegroups":"retail-store-grp5-ng-application"}}},"stopConditions":[{"source":"none"}],"roleArn":"'$FIS_ROLE_ARN'","tags":{"ExperimentSuffix": "DEMO"}}' --output json | jq -r '.experimentTemplate.id')
```

```bash
aws fis start-experiment --experiment-template-id $NODE_EXP_ID --output json
```
