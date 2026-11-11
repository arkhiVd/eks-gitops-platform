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

variable "cluster_name" {
  description = "EKS cluster name. Also the Karpenter discovery tag value."
  type        = string
  default     = "eks-gitops"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version. Must match SPEC.md."
  type        = string
  default     = "1.37"
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.40.0.0/16"
}

variable "operator_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint. Set in terraform.tfvars (gitignored)."
  type        = list(string)

  validation {
    condition     = length(var.operator_cidrs) > 0 && !contains(var.operator_cidrs, "0.0.0.0/0")
    error_message = "operator_cidrs must list at least one CIDR and must not be 0.0.0.0/0."
  }
}

variable "node_instance_type" {
  description = "Instance type for the managed node group. FREE plan accounts can launch only free-tier-eligible types."
  type        = string
  default     = "m7i-flex.large"
}

variable "gitops_repo_url" {
  description = "Git repository Argo CD syncs from (public, read anonymously)."
  type        = string
  default     = "https://github.com/arkhiVd/eks-gitops-platform.git"
}

variable "gitops_revision" {
  description = "Branch Argo CD tracks. A feature branch while a PR is tested, main otherwise."
  type        = string
  default     = "main"
}
