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
├── helm/
│   ├── values/
│   └── helmfile.yaml.gotmpl
├── manifests/
│   ├── adot/
│   ├── carts/
│   ├── catalog/
│   ├── checkout/
│   ├── crds/
│   ├── fluentbit/
│   ├── grafana/
│   ├── load-gen/
│   ├── orders/
│   ├── ui/
│   └── kustomization.yaml
├── terraform/
├── .gitignore
└── README.md
```

## How to startup

### Provision VPC, EKS Cluster, Helm Installation of Services

```bash
cd terraform
terraform init
terraform apply
```

### Helm Chart installation

```bash
aws eks --region ap-southeast-1 update-kubeconfig --name retail-store-grp5
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export VPC_ID=$(aws eks describe-cluster --name retail-store-grp5 --region ap-southeast-1 --query 'cluster.resourcesVpcConfig.vpcId' --output text)
helmfile -f helm/helmfile.yaml.gotmpl lint
helmfile -f helm/helmfile.yaml.gotmpl sync
helmfile -f helm/helmfile.yaml.gotmpl list
```

Validation:

```bash
kubectl get pods -n kube-system  # shows aws-load-balancer-controller healthy.
kubectl get pods -n external-dns # shows external-dns healthy.
kubectl get pods -n monitoring   # shows prometheus/grafana healthy.
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
kubectl -get all -A
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

## Useful commands

### Get Grafana Admin Password

```bash
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```
