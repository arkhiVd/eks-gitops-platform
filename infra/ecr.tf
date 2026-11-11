# Image repositories for the chain services. CI pushes here through the bootstrap OIDC role,
# which may write only to repository/eks-gitops/*. Nodes pull with their node role.
locals {
  services = toset(["fe", "app1", "app2"])
}

resource "aws_ecr_repository" "service" {
  # checkov:skip=CKV_AWS_136:AES256 instead of a KMS key ($1/month) for a 9-day project
  for_each = local.services

  name                 = "eks-gitops/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true # Phase 7 teardown deletes repos that still hold images

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "service" {
  for_each   = aws_ecr_repository.service
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the 10 newest images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

output "ecr_repository_urls" {
  description = "Repository URL per service."
  value       = { for k, r in aws_ecr_repository.service : k => r.repository_url }
}
