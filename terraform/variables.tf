variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "retail-store-grp5"
}

variable "cluster_version" {
  description = "EKS cluster version."
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "Defines the CIDR block used on Amazon VPC created for Amazon EKS."
  type        = string
  default     = "10.42.0.0/16"
}

variable "aws_region" {
  description = "AWS region to deploy the EKS cluster"
  type        = string
  default     = "ap-southeast-1"
}

variable "cluster_admins" {
  type = set(string)
  default = [
    "Arista",
    "Gohshg",
    "indysctpce26",
    "mfaizalbe",
    "szekongchan"
  ]
}