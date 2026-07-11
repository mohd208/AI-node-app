# Auto-loaded by Terraform (*.auto.tfvars) -- takes precedence over any
# example file. Written by the deploy agent for this specific request:
#   issue: DEVOPS-101, repo: mohd208/AI-node-app, env: staging
#
# aws_region / eks_cluster_name are placeholders for this test run -- no
# EKS_CONFIG_SECRET_ID / AWS account was available to resolve real values
# from (see instructions/secrets-flow.md). Replace with the platform team's
# actual staging cluster/region before `terraform apply` is ever run.
aws_region       = "us-east-1"
app_name         = "ai-node-app"
namespace        = "ai-node-app-staging"
environment      = "staging"
github_org       = "mohd208"
github_repo      = "AI-node-app"
target_branch    = "stage"
eks_cluster_name = "rtctek-staging-eks"

# Live ecr:DescribeRepositories check found no existing "ai-node-app"
# repository -- main.tf creates it.
ecr_repository_exists = false

# No existing token.actions.githubusercontent.com OIDC provider was found
# (read-only iam:ListOpenIDConnectProviders check) -- github-oidc.tf creates
# it and this repo's deploy role.
create_github_oidc_provider = true
existing_github_oidc_provider_arn = ""

secrets_manager_prefix = "/apps"

# deploy/secret-vars.staging.yaml did not exist yet, so the agent created a
# starter with a single EXAMPLE_SECRET placeholder (see that file) and left
# both lists below empty -- no runtime or pipeline secrets exist yet to wire
# into IAM.
secret_names        = []
pipeline_secret_ids = []
