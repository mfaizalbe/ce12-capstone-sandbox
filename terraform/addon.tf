resource "kubernetes_namespace_v1" "external_dns" {
  depends_on = [module.eks]

  metadata {
    name = "external-dns"
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 900
  atomic           = true
  cleanup_on_fail  = true
  depends_on       = [module.eks, kubernetes_service_account_v1.aws_load_balancer_controller]

  values = [
    yamlencode({
      clusterName                 = var.cluster_name
      vpcId                       = module.vpc.vpc_id
      region                      = var.aws_region
      enableServiceMutatorWebhook = false

      serviceAccount = {
        create = false
        name   = "aws-load-balancer-controller-sa"
      }
    })
  ]
}

resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = "1.21.1" # Standard stable chart version
  namespace        = kubernetes_namespace_v1.external_dns.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 900
  atomic           = true
  cleanup_on_fail  = true
  depends_on       = [module.eks, helm_release.aws_load_balancer_controller, kubernetes_namespace_v1.external_dns]

  # Pass the Helm configuration values
  values = [
    yamlencode({
      provider = "aws"

      # Unique cluster identifier to prevent conflicts if sharing a Route53 zone
      txtOwnerId = var.cluster_name

      serviceAccount = {
        create = false
        name   = "external-dns"
        annotations = {
          # Binds the IRSA Role ARN dynamically from your IAM module
          "eks.amazonaws.com/role-arn" = module.external_dns_role.iam_role_arn
        }
      }

      # Standard security context adjustments for running in EKS
      securityContext = {
        runAsNonRoot = true
        runAsUser    = 65534
        fsGroup      = 65534
      }
    })
  ]
}

resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack" # Changed to install both Prometheus & Grafana
  version          = "69.0.0"                # Standard stable stack chart version
  namespace        = "monitoring"
  create_namespace = true
  wait             = true
  timeout          = 900
  atomic           = true
  cleanup_on_fail  = true

  depends_on = [
    module.eks,
    helm_release.aws_load_balancer_controller # Ensures routing layer is ready first
  ]

  # Pass the Helm configuration values
  values = [
    yamlencode({
      # Enable core components
      prometheus = {
        enabled = true
      }

      alertmanager = {
        enabled = true
      }

      grafana = {
        enabled = true

        service = {
          type = "ClusterIP"
        }

        ingress = {
          enabled          = true
          ingressClassName = "alb"

          annotations = {
            "alb.ingress.kubernetes.io/group.name"      = "grp5-app-alb"
            "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"     = "ip"
            "external-dns.alpha.kubernetes.io/hostname" = "grp5-grafana.sctp-sandbox.com"

            "alb.ingress.kubernetes.io/healthcheck-path" = "/api/health"
            "alb.ingress.kubernetes.io/healthcheck-port" = "traffic-port"
          }

          hosts = [
            "grp5-grafana.sctp-sandbox.com"
          ]

          path = "/"
        }
      }
    })
  ]
}
