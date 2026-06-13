module "lb_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name                              = "${var.cluster_name}-aws-load-balancer-controller-irsa"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller-sa"]
    }
  }
}

module "external_dns_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name                  = "${var.cluster_name}-external-dns-irsa"
  attach_external_dns_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }
}

resource "kubernetes_service_account_v1" "aws_load_balancer_controller" {
  depends_on = [module.eks]

  metadata {
    name      = "aws-load-balancer-controller-sa"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.lb_role.iam_role_arn
    }
  }
}

resource "kubernetes_service_account_v1" "external_dns" {
  depends_on = [module.eks, kubernetes_namespace_v1.external_dns]

  metadata {
    name      = "external-dns"
    namespace = "external-dns"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.external_dns_role.iam_role_arn
    }
  }

}