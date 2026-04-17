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

## initial ideas discussed by the team for preparing the demo.
### preparation checklist
- Confirm demo features
- Identify source code for deployment
- Design cloud architecture
- Develop Terraform code
- Deploy application and test
- Implement CI/CD (optional)
- Prepare demo flow

### AWS services & tools to consider
🖥️ Compute = EC2 / Lambda / ECS / EKS  
💾 Storage = S3 / EBS / EFS  
🗄️ Database = RDS / DynamoDB / Aurora / ElastiCache  
🌐 Networking = VPC / ALB / NLB / Route 53 / CloudFront / API Gateway  
🔐 Security = IAM / KMS / Security Groups / WAF  
⚙️ DevOps = Terraform / CloudFormation / GitHub Actions  
🐳 Containers = Docker / ECS / EKS / ECR  
📊 Monitoring & Logging = CloudWatch / CloudTrail / X-Ray  
🔄 Messaging & Events = SQS / SNS / EventBridge  

> Note: The final architecture will use only a subset of these services depending on the demo requirements.