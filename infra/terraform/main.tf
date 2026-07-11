terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # No shared Terraform state bucket/lock table was available to check or
  # create for this test run (CLAUDE_STATE_BACKEND_BOOTSTRAP_ENABLED was not
  # set), so this stays on local state for now. Once the platform team
  # provisions <PROJECT_NAME>-terraform-state / <PROJECT_NAME>-terraform-locks,
  # add a literal backend "s3" block here (bucket/key/region/dynamodb_table),
  # matching every other app's convention -- see instructions/pr-plan.md.
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# The EKS cluster (and its VPC/subnets/NAT/IGW) is provisioned once by the
# platform team -- this only looks it up, never creates/modifies it.
data "aws_eks_cluster" "this" {
  name = var.eks_cluster_name
}

data "aws_eks_node_group" "nodegroups" {
  for_each        = toset(var.eks_nodegroups)
  cluster_name    = var.eks_cluster_name
  node_group_name = each.value
}

# ecr_repository_exists is a live ecr:DescribeRepositories check the agent
# runs before writing terraform.auto.tfvars -- not yet found for this app, so
# it is created below instead of looked up.
data "aws_ecr_repository" "existing" {
  count = var.ecr_repository_exists ? 1 : 0
  name  = var.app_name
}

resource "aws_ecr_repository" "app" {
  count                = var.ecr_repository_exists ? 0 : 1
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  count      = var.ecr_repository_exists ? 0 : 1
  repository = aws_ecr_repository.app[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the last 30 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

locals {
  ecr_repository_url  = var.ecr_repository_exists ? data.aws_ecr_repository.existing[0].repository_url : aws_ecr_repository.app[0].repository_url
  ecr_repository_name = var.app_name
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "ecr_repository_url" {
  value = local.ecr_repository_url
}

output "ecr_repository_name" {
  value = local.ecr_repository_name
}

output "eks_cluster_oidc_issuer_url" {
  value = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "eks_cluster_role_arn" {
  value = data.aws_eks_cluster.this.role_arn
}

output "eks_node_group_role_arns" {
  value = { for name, ng in data.aws_eks_node_group.nodegroups : name => ng.node_role_arn }
}

output "terraform_state_bucket" {
  value = var.state_bucket_name
}

output "terraform_state_lock_table" {
  value = var.state_lock_table_name
}
