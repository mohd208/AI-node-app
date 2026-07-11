variable "aws_region" {
  type        = string
  description = "AWS region for ECR, EKS, and Secrets Manager."
}

variable "app_name" {
  type        = string
  description = "Application name. Used for the ECR repository, IAM role names, and the Secrets Manager path."
}

variable "environment" {
  type        = string
  description = "Deployment environment: dev, staging, or prod."
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace the app is deployed into."
}

variable "eks_cluster_name" {
  type        = string
  description = "Name of the existing EKS cluster this app deploys to. The cluster itself is provisioned once by the platform team, not by this per-app Terraform."
}

variable "eks_nodegroups" {
  type        = list(string)
  description = "Names of this EKS cluster's existing node groups, from the agent's EKS config (agent_core/secrets.py::resolve_aws_context). Looked up read-only (main.tf) to expose their role ARNs as outputs for pipeline visibility -- never created or modified here, since a running cluster's node groups always already exist. Leave empty to skip the lookup."
  default     = []
}

variable "github_org" {
  type        = string
  description = "GitHub organization or user that owns the application repository."
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (without owner)."
}

variable "target_branch" {
  type        = string
  description = "Branch GitHub Actions must be running against to assume the deploy role, e.g. main."
}

variable "create_github_oidc_provider" {
  type        = bool
  description = "Create the GitHub Actions OIDC provider. Set to false if one already exists in this AWS account and set existing_github_oidc_provider_arn instead."
  default     = true
}

variable "existing_github_oidc_provider_arn" {
  type        = string
  description = "ARN of an existing GitHub Actions OIDC provider. Only used when create_github_oidc_provider is false."
  default     = ""
}

variable "github_actions_role_exists" {
  type        = bool
  description = "Whether the agent already created this repo's github-actions-{app_name}-{environment}-deploy role directly via AWS (agent_core/oidc.py), before this Terraform ever ran. When true, the role is only looked up (data source) and its trust policy is left alone -- Terraform still creates and attaches the permissions policy either way. Defaults to false: Terraform creates the role itself, same as before this existed."
  default     = false
}

variable "ecr_repository_exists" {
  type        = bool
  description = "Whether an ECR repository named app_name already exists in this account. When true, this repo is only looked up (data source), never created, so re-running this Terraform for an existing app doesn't fail or duplicate anything."
  default     = false
}

variable "secrets_manager_prefix" {
  type        = string
  description = "Base path under which this app's runtime secrets live in AWS Secrets Manager."
  default     = "/apps"
}

variable "secret_names" {
  type        = list(string)
  description = "Names of secret-vars.yaml entries classified as scope: runtime (or unscoped and inferred as runtime). Used to scope the app pod's IAM role (irsa.tf) to exactly these secrets -- never broader. Leave empty if the app has no runtime secrets yet."
  default     = []
}

variable "pipeline_secret_ids" {
  type        = list(string)
  description = "AWS Secrets Manager secret IDs (full ARNs or names) for secret-vars.yaml entries classified as scope: pipeline -- secrets the CI/CD workflow itself needs (e.g. a monitoring agent API key, a notification webhook token), not the running app. Whatever a secret is named, if it belongs here it gets exactly one read-only statement below; nothing is hardcoded to a specific secret name or vendor. Leave empty if this app has no pipeline-level secrets."
  default     = []
}

### These two exist ONLY so the state bucket/table name can appear in
### `terraform output` (and from there, a GitHub environment variable) for
### pipeline visibility/debugging. Terraform's own backend block (see the
### top of main.tf) cannot reference variables -- these must be kept in
### sync with that block's literal bucket/dynamodb_table by hand (or by
### whatever writes both at once), they don't drive the actual backend.
variable "state_bucket_name" {
  type        = string
  description = "The literal bucket name already set in main.tf's backend \"s3\" block -- repeated here only so it can be exposed as a Terraform output."
  default     = ""
}

variable "state_lock_table_name" {
  type        = string
  description = "The literal dynamodb_table name already set in main.tf's backend \"s3\" block -- repeated here only so it can be exposed as a Terraform output."
  default     = ""
}
