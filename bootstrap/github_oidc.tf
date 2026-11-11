# GitHub Actions OIDC trust. CI gets exactly one role: push images to this project's ECR
# repositories from the main branch. It has no EKS, Terraform state or Kubernetes access.

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

locals {
  # GitHub can emit the subject with names (repo:owner/repo:...) or with immutable IDs
  # (repo:owner@id/repo@id:...). Both forms are pinned to main. The ID form survives a
  # rename and cannot be claimed by a recreated repo of the same name. Phase 1 records which
  # form this repo emits (oidc-probe workflow); the other one is then removed.
  push_subjects = [
    "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/main",
    "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:ref:refs/heads/main",
  ]
}

data "aws_iam_policy_document" "ecr_push_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.push_subjects
    }
  }
}

resource "aws_iam_role" "ecr_push" {
  name                 = "eks-gitops-gha-ecr-push"
  description          = "GitHub Actions on ${var.github_owner}/${var.github_repo} main: push images to ECR only"
  assume_role_policy   = data.aws_iam_policy_document.ecr_push_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid       = "EcrLogin"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # this action does not support resource-level permissions
  }

  statement {
    sid    = "PushProjectRepos"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [
      "arn:aws:ecr:${var.region}:${var.account_id}:repository/${var.ecr_repo_prefix}/*",
    ]
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push-project-repos"
  role   = aws_iam_role.ecr_push.id
  policy = data.aws_iam_policy_document.ecr_push.json
}
