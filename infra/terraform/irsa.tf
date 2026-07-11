### Per-app pod identity (IRSA): lets this app's own Kubernetes pods read
### exactly the secrets listed in its deploy/secret-vars.yaml -- nothing
### broader. This is a different OIDC provider than github-oidc.tf's: that
### one is GitHub Actions' OIDC issuer, used only by the CI pipeline; this
### one is the EKS cluster's own OIDC issuer, used only by pods running
### inside the cluster. The cluster's OIDC provider is registered once when
### the cluster itself is created (by the platform team) -- this file only
### looks it up, it never creates it.

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

locals {
  eks_oidc_issuer_host = replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
  has_secrets          = length(var.secret_names) > 0
}

data "aws_iam_policy_document" "app_pod_assume_role" {
  count = local.has_secrets ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    ### Restrict to this app's own namespace + service account -- another
    ### app's pods in another namespace cannot assume this role.
    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.app_name}"]
    }
  }
}

resource "aws_iam_role" "app_pod" {
  count              = local.has_secrets ? 1 : 0
  name               = "${var.app_name}-${var.environment}-pod"
  assume_role_policy = data.aws_iam_policy_document.app_pod_assume_role[0].json
}

data "aws_iam_policy_document" "app_pod_secrets" {
  count = local.has_secrets ? 1 : 0

  statement {
    sid    = "ReadOwnRuntimeSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      for secret_name in var.secret_names :
      "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.secrets_manager_prefix}/${var.environment}/${var.app_name}/${secret_name}*"
    ]
  }
}

resource "aws_iam_policy" "app_pod_secrets" {
  count  = local.has_secrets ? 1 : 0
  name   = "${var.app_name}-${var.environment}-pod-secrets"
  policy = data.aws_iam_policy_document.app_pod_secrets[0].json
}

resource "aws_iam_role_policy_attachment" "app_pod_secrets" {
  count      = local.has_secrets ? 1 : 0
  role       = aws_iam_role.app_pod[0].name
  policy_arn = aws_iam_policy.app_pod_secrets[0].arn
}

### Empty string when the app has no secrets yet (secret_names = []) --
### deploy/k8s/pod-identity.yaml is only annotated with this ARN once it's
### non-empty, so an app with no secrets doesn't get an unused IAM role.
output "app_pod_role_arn" {
  value = local.has_secrets ? aws_iam_role.app_pod[0].arn : ""
}
