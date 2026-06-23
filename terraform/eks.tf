module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                                     = var.cluster_name
  kubernetes_version                       = var.cluster_version
  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = false

  enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  create_cloudwatch_log_group            = true
  cloudwatch_log_group_retention_in_days = 30

  access_entries = {
    for username in var.cluster_admins :
    username => {
      principal_arn = "arn:aws:iam::255945442255:user/${username}"
      type          = "STANDARD"

      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
      most_recent    = true
      configuration_values = jsonencode({
        env = {
          ENABLE_POD_ENI                    = "true"
          ENABLE_PREFIX_DELEGATION          = "true"
          POD_SECURITY_GROUP_ENFORCING_MODE = "standard"
        }
        nodeAgent = {
          enablePolicyEventLogs = "true"
        }
        enableNetworkPolicy = "true"
      })
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_security_group      = false
  create_node_security_group = false

  eks_managed_node_groups = {
    application = {
      name                     = "${var.cluster_name}-ng-application"
      instance_types           = ["t3.medium"] # ["m5.large"]
      force_update_version     = true
      release_version          = "1.33.0-20250704"
      use_name_prefix          = false
      iam_role_name            = "${var.cluster_name}-ng-application"
      iam_role_use_name_prefix = false

      min_size     = 3
      max_size     = 5
      desired_size = 3

      update_config = {
        max_unavailable_percentage = 50
      }

      labels = {
        workload = "application"
      }

      tags = {
        Name = "${var.cluster_name}-ng-application"
      }
    }

    observability = {
      name                     = "${var.cluster_name}-ng-observability"
      instance_types           = ["t3.medium"]
      force_update_version     = true
      release_version          = "1.33.0-20250704"
      use_name_prefix          = false
      iam_role_name            = "${var.cluster_name}-ng-observability"
      iam_role_use_name_prefix = false
      subnet_ids               = [module.vpc.private_subnets[index(local.azs, "ap-southeast-1c")]]

      min_size     = 2
      max_size     = 3  
      desired_size = 2

      update_config = {
        max_unavailable_percentage = 50
      }

      labels = {
        workload = "observability"
      }

      taints = {
        observability = {
          key    = "workload"
          value  = "observability"
          effect = "NO_SCHEDULE"
        }
      }

      tags = {
        Name = "${var.cluster_name}-ng-observability"
      }
    }
  }

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = var.cluster_name
  })
}
