# service accounts
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

data "aws_iam_policy_document" "fluent_bit_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:monitoring:fluent-bit"]
    }
  }
}

data "aws_iam_policy_document" "fluent_bit_cloudwatch" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:*:log-group:/aws/containerinsights/${var.cluster_name}*",
      "arn:aws:logs:${var.aws_region}:*:log-group:/aws/containerinsights/${var.cluster_name}*:log-stream:*"
    ]
  }
}

resource "aws_iam_role" "fluent_bit_irsa" {
  name               = "${var.cluster_name}-fluent-bit-irsa"
  assume_role_policy = data.aws_iam_policy_document.fluent_bit_assume_role.json
}

resource "aws_iam_policy" "fluent_bit_cloudwatch" {
  name   = "${var.cluster_name}-fluent-bit-cloudwatch"
  policy = data.aws_iam_policy_document.fluent_bit_cloudwatch.json
}

resource "aws_iam_role_policy_attachment" "fluent_bit_cloudwatch" {
  role       = aws_iam_role.fluent_bit_irsa.name
  policy_arn = aws_iam_policy.fluent_bit_cloudwatch.arn
}

data "aws_iam_policy_document" "grafana_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:monitoring:prometheus-grafana"]
    }
  }
}

data "aws_iam_policy_document" "grafana_cloudwatch_read" {
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:FilterLogEvents",
      "logs:GetLogGroupFields",
      "logs:GetLogRecord",
      "logs:GetQueryResults",
      "logs:StartQuery",
      "logs:StopQuery",
      "ec2:DescribeRegions",
      "tag:GetResources"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "grafana_irsa" {
  name               = "${var.cluster_name}-grafana-irsa"
  assume_role_policy = data.aws_iam_policy_document.grafana_assume_role.json
}

resource "aws_iam_policy" "grafana_cloudwatch_read" {
  name   = "${var.cluster_name}-grafana-cloudwatch-read"
  policy = data.aws_iam_policy_document.grafana_cloudwatch_read.json
}

resource "aws_iam_role_policy_attachment" "grafana_cloudwatch_read" {
  role       = aws_iam_role.grafana_irsa.name
  policy_arn = aws_iam_policy.grafana_cloudwatch_read.arn
}

data "aws_iam_policy_document" "grafana_xray_read" {
  statement {
    effect = "Allow"
    actions = [
      "xray:BatchGetTraces",
      "xray:GetTraceSummaries",
      "xray:GetTraceGraph",
      "xray:GetGroups",
      "xray:GetTimeSeriesServiceStatistics",
      "xray:GetInsightSummaries",
      "xray:GetInsight",
      "ec2:DescribeRegions"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "grafana_xray_read" {
  name   = "${var.cluster_name}-grafana-xray-read"
  policy = data.aws_iam_policy_document.grafana_xray_read.json
}

resource "aws_iam_role_policy_attachment" "grafana_xray_read" {
  role       = aws_iam_role.grafana_irsa.name
  policy_arn = aws_iam_policy.grafana_xray_read.arn
}

data "aws_iam_policy_document" "loki_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:monitoring:loki"]
    }
  }
}

data "aws_iam_policy_document" "loki_s3" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.loki_bucket_name}"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::${var.loki_bucket_name}/*"
    ]
  }
}

resource "aws_iam_role" "loki_irsa" {
  name               = "${var.cluster_name}-loki-irsa"
  assume_role_policy = data.aws_iam_policy_document.loki_assume_role.json
}

resource "aws_iam_policy" "loki_s3" {
  name   = "${var.cluster_name}-loki-s3"
  policy = data.aws_iam_policy_document.loki_s3.json
}

resource "aws_iam_role_policy_attachment" "loki_s3" {
  role       = aws_iam_role.loki_irsa.name
  policy_arn = aws_iam_policy.loki_s3.arn
}

data "aws_iam_policy_document" "adot_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:monitoring:adot-collector"]
    }
  }
}

data "aws_iam_policy_document" "adot_xray_write" {
  statement {
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "adot_irsa" {
  name               = "${var.cluster_name}-adot-irsa"
  assume_role_policy = data.aws_iam_policy_document.adot_assume_role.json
}

resource "aws_iam_policy" "adot_xray_write" {
  name   = "${var.cluster_name}-adot-xray-write"
  policy = data.aws_iam_policy_document.adot_xray_write.json
}

resource "aws_iam_role_policy_attachment" "adot_xray_write" {
  role       = aws_iam_role.adot_irsa.name
  policy_arn = aws_iam_policy.adot_xray_write.arn
}

data "aws_iam_policy_document" "fis_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["fis.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "fis_node_termination" {
  statement {
    effect = "Allow"
    actions = [
      "eks:DescribeNodegroup",
      "eks:ListNodegroups"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:TerminateInstances"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "fis_role" {
  name               = "${var.cluster_name}-fis-role"
  assume_role_policy = data.aws_iam_policy_document.fis_assume_role.json
}

resource "aws_iam_policy" "fis_node_termination" {
  name   = "${var.cluster_name}-fis-node-termination"
  policy = data.aws_iam_policy_document.fis_node_termination.json
}

resource "aws_iam_role_policy_attachment" "fis_node_termination" {
  role       = aws_iam_role.fis_role.name
  policy_arn = aws_iam_policy.fis_node_termination.arn
}