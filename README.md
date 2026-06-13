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
├── manifests/
│   ├── carts/
│   ├── catalog/
│   ├── checkout/
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

### Start Application

```bash
aws eks --region ap-southeast-1 update-kubeconfig --name retail-store-grp5
kubectl apply -k manifests
```

## Useful URL

- Store: http://grp5.sctp-sandbox.com/
- Grafana: http://http://grp5-grafana.sctp-sandbox.com/

## Useful commands

### Get Grafana Admin Password

```bash
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```
