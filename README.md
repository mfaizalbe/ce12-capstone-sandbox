# ce12-capstone-sandbox
Sandbox repository for the CE12 DevOps Capstone project to experiment with application code, infrastructure, CI/CD, monitoring, and security.

## initial project structure (subject to refinement)
```text
ce12-capstone-sandbox/
│
├── app/
│   ├── src/
│   │   ├── controllers/
│   │   ├── routes/
│   │   ├── models/
│   │   └── app.js
│   │
│   ├── tests/
│   │   └── app.test.js
│   │
│   ├── package.json
│   └── package-lock.json
│
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
│
├── infra/
│   └── terraform/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       │
│       ├── modules/
│       │   ├── ec2/
│       │   ├── alb/
│       │   ├── iam/
│       │   └── security-group/
│       │
│       └── env/
│           ├── dev.tfvars
│           ├── staging.tfvars
│           └── prod.tfvars
│
├── monitoring/
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── alert.rules.yml
│   │
│   ├── grafana/
│   │   ├── dashboards/
│   │   └── provisioning/
│   │
│   └── docker-compose.monitoring.yml
│
├── security/
│   ├── iam/
│   ├── secrets/
│   └── scanning/
│
├── scripts/
│   ├── build.sh
│   ├── deploy.sh
│   └── terraform-deploy.sh
│
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── cd.yml
│       └── security-scan.yml
│
├── docs/
│   ├── architecture.md
│   ├── ci-cd.md
│   ├── terraform.md
│   ├── monitoring.md
│   └── screenshots/
│
├── docker-compose.yml
├── Makefile
├── .gitignore
└── README.md
```