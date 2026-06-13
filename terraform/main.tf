locals {
  tags = {
    created-by = "eks-workshop"
    env        = var.cluster_name
  }

  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 3, k + 3)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 3, k)]
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)

  remote_node_cidr = var.remote_network_cidr
  remote_pod_cidr  = var.remote_pod_cidr
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "kubernetes_namespace_v1" "load-gen" {
  depends_on = [module.eks]

  metadata {
    name = "load-gen"
  }
}