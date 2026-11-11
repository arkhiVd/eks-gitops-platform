terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.72"
    }
  }

  # Bucket comes from bootstrap/. Native S3 lockfile, no DynamoDB table.
  backend "s3" {
    bucket       = "eks-gitops-tfstate-348032171026"
    key          = "infra/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      project    = "eks-gitops-platform"
      owner      = "arkhiVd"
      stack      = "infra"
      managed-by = "terraform"
    }
  }
}
