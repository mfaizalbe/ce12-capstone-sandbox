module "lb_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.6.0"

  name                                   = "${var.cluster_name}-aws-load-balancer-controller-irsa"
  use_name_prefix                        = false
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller-sa"]
    }
  }
}

module "external_dns_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.6.0"

  name                       = "${var.cluster_name}-external-dns-irsa"
  use_name_prefix            = false
  attach_external_dns_policy = true

  external_dns_hosted_zone_arns = [
    "arn:aws:route53:::hostedzone/*"
  ]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }
}

module "ebs_csi_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.6.0"

  name                  = "${var.cluster_name}-ebs-csi-irsa"
  use_name_prefix       = false
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "kubernetes_service_account_v1" "aws_load_balancer_controller" {
  depends_on = [module.eks]
  metadata {
    name      = "aws-load-balancer-controller-sa"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.lb_role.arn
    }
  }
}

resource "kubernetes_service_account_v1" "external_dns" {
  depends_on = [module.eks, kubernetes_namespace_v1.external_dns]
  metadata {
    name      = "external-dns"
    namespace = "external-dns"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.external_dns_role.arn
    }
  }
}
