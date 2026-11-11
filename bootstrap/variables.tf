variable "region" {
  description = "AWS region for every resource in this project."
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "The only AWS account this stack may touch (free-plan account)."
  type        = string
  default     = "348032171026"
}

variable "github_owner" {
  description = "GitHub owner login."
  type        = string
  default     = "arkhiVd"
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
  default     = "eks-gitops-platform"
}

variable "github_owner_id" {
  description = "Numeric GitHub owner ID, for immutable OIDC subject claims."
  type        = string
  default     = "95763443"
}

variable "github_repo_id" {
  description = "Numeric GitHub repository ID, for immutable OIDC subject claims."
  type        = string
  default     = "1453514477"
}

variable "ecr_repo_prefix" {
  description = "ECR repository name prefix the CI push role may write to."
  type        = string
  default     = "eks-gitops"
}

variable "state_bucket_force_destroy" {
  description = "Allow destroy of a non-empty state bucket. Set true only for the Phase 7 teardown."
  type        = bool
  default     = false
}
