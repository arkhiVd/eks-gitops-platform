terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.72"
    }
  }

  # Local state on purpose: this stack creates the bucket that holds infra/ state.
  # The state file stays on the operator's machine and is gitignored.
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      project    = "eks-gitops-platform"
      owner      = "arkhiVd"
      stack      = "bootstrap"
      managed-by = "terraform"
    }
  }
}
