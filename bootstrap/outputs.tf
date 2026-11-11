output "state_bucket" {
  description = "S3 bucket for infra/ remote state."
  value       = aws_s3_bucket.state.bucket
}

output "github_oidc_provider_arn" {
  description = "IAM OIDC provider for GitHub Actions."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "ecr_push_role_arn" {
  description = "Role GitHub Actions assumes on main to push images. Goes in the app workflow."
  value       = aws_iam_role.ecr_push.arn
}
