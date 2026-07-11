### GitHub Actions OIDC for AWS deploys.
###
### Every value below comes from a real Terraform variable (see variables.tf),
### populated with this app's actual owner/repo/branch by the agent when it
### writes infra/terraform/terraform.auto.tfvars. Nothing here is a literal
### placeholder string waiting on a manual find/replace -- if it were, the
### role's trust condition would never match a real GitHub Actions run and
### the pipeline could never assume this role.
###
### If your AWS account already has a GitHub OIDC provider, set:
###   create_github_oidc_provider = false
###   existing_github_oidc_provider_arn = "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
###
### If the agent already created this repo's deploy role directly via AWS
### (agent_core/oidc.py, gated behind CLAUDE_OIDC_BOOTSTRAP_ENABLED) before
### this Terraform ever ran, set:
###   github_actions_role_exists = true
### The role is then only looked up (data source), never re-created -- but
### its PERMISSIONS POLICY is still fully managed below either way. That
### split exists because a `data` source can't modify the role it reads, so
### the agent (not Terraform) owns the trust policy once the role exists,
### while Terraform always owns what the role is allowed to do.

locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github_actions[0].arn : var.existing_github_oidc_provider_arn
  github_repo_subject      = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.target_branch}"
  deploy_role_name         = "github-actions-${var.app_name}-${var.environment}-deploy"
  deploy_role_arn          = var.github_actions_role_exists ? data.aws_iam_role.github_actions_deploy_existing[0].arn : aws_iam_role.github_actions_deploy[0].arn
  deploy_role_name_ref     = var.github_actions_role_exists ? data.aws_iam_role.github_actions_deploy_existing[0].name : aws_iam_role.github_actions_deploy[0].name
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  count = var.create_github_oidc_provider ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"
      identifiers = [
        local.github_oidc_provider_arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    ### Scoped to this exact repo and this exact target branch -- any other
    ### repo, fork, or branch cannot assume this role.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.github_repo_subject]
    }
  }
}

### Only one of these two exists for a given apply -- see
### github_actions_role_exists above.

resource "aws_iam_role" "github_actions_deploy" {
  count              = var.github_actions_role_exists ? 0 : 1
  name               = local.deploy_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

data "aws_iam_role" "github_actions_deploy_existing" {
  count = var.github_actions_role_exists ? 1 : 0
  name  = local.deploy_role_name
}

data "aws_iam_policy_document" "github_actions_deploy" {
  statement {
    sid    = "EcrLogin"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EcrPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeRepositories",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.app_name}"
    ]
  }

  statement {
    sid    = "EksDeploy"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster"
    ]
    resources = [
      "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_cluster_name}"
    ]
  }

  ### CI-time reads only, one statement per pipeline_secret_ids entry --
  ### these come from deploy/secret-vars.yaml entries the agent classified
  ### as scope: pipeline (a monitoring key, a notification webhook, etc.),
  ### never from a hardcoded vendor-specific slot. The running pod reads its
  ### own runtime secrets through the separate IRSA role in irsa.tf instead,
  ### scoped only to var.secret_names -- this deploy role never gets blanket
  ### access to the app's runtime secrets.
  dynamic "statement" {
    for_each = length(var.pipeline_secret_ids) > 0 ? [1] : []
    content {
      sid    = "ReadPipelineSecrets"
      effect = "Allow"
      actions = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue"
      ]
      resources = [
        for secret_id in var.pipeline_secret_ids :
        "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${secret_id}*"
      ]
    }
  }
}

### Terraform always creates and attaches this policy, regardless of
### whether the role above was created here or already existed -- the agent
### only ever manages the role's trust policy, never its permissions.
resource "aws_iam_policy" "github_actions_deploy" {
  name   = local.deploy_role_name
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}

resource "aws_iam_role_policy_attachment" "github_actions_deploy" {
  role       = local.deploy_role_name_ref
  policy_arn = aws_iam_policy.github_actions_deploy.arn
}

output "github_actions_deploy_role_arn" {
  value = local.deploy_role_arn
}
