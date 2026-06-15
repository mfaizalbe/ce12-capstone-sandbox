provider "aws" {
  default_tags {
    tags = local.tags
  }
}

terraform {
  backend "s3" {
    bucket               = "capstone-project-group5"
    key                  = "eks/default/terraform.tfstate"
    region               = "ap-southeast-1"
    use_lockfile         = true
    workspace_key_prefix = "workspaces"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.67.0"
    }
  }

  required_version = ">= 1.4.2"
}
