resource "kubernetes_namespace_v1" "external_dns" {
  depends_on = [module.eks]

  metadata {
    name = "external-dns"
  }
}

data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml"
}

data "kubectl_file_documents" "gateway_api_docs" {
  content = data.http.gateway_api_crds.response_body
}

resource "kubectl_manifest" "gateway_api_crd" {
  for_each = data.kubectl_file_documents.gateway_api_docs.manifests

  yaml_body         = each.value
  server_side_apply = true
  wait              = true
}

data "aws_eks_addon_version" "ebs_csi_driver" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = var.cluster_version
  most_recent        = true
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.ebs_csi_driver.version
  service_account_role_arn    = module.ebs_csi_role.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [module.eks, module.ebs_csi_role]
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
  depends_on = [
    module.eks,
    kubernetes_service_account_v1.aws_load_balancer_controller,
    kubectl_manifest.gateway_api_crd
  ]

  values = [
    yamlencode({
      clusterName                 = var.cluster_name
      vpcId                       = module.vpc.vpc_id
      region                      = var.aws_region
      enableServiceMutatorWebhook = false
      defaultTargetType           = "ip"

      controllerConfig = {
        featureGates = {
          "ALBGatewayAPI" = true
        }
      }

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
      sources  = ["service", "ingress", "gateway-httproute"]

      # Unique cluster identifier to prevent conflicts if sharing a Route53 zone
      txtOwnerId = var.cluster_name

      serviceAccount = {
        create = false
        name   = "external-dns"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.external_dns_role.arn
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
          enabled = false
        }
      }
    })
  ]
}

resource "kubectl_manifest" "grafana_httproute" {
  depends_on = [helm_release.prometheus]

  yaml_body = <<-YAML
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: grafana-route
  namespace: monitoring
spec:
  hostnames:
    - grp5-grafana.sctp-sandbox.com
  parentRefs:
    - name: retail-store-gateway
      namespace: ui
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: prometheus-grafana
          port: 80
YAML
}
