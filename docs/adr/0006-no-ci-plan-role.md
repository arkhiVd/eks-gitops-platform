# 0006. No Terraform plan or apply in CI

Status: accepted, 2026-11-11

## Context

Running `terraform plan` on `infra/` in CI is common. Here it would need Kubernetes API access,
because the Helm releases for the Load Balancer Controller and Argo CD read cluster state
during plan. Giving CI that access breaks the claim in 0001.

## Decision

CI runs static checks only: `terraform fmt` and `validate`, `tflint`, `checkov`, `trivy config`,
`gitleaks`, `actionlint` and `kubeconform` on raw and rendered manifests. The operator runs
`plan -out=tfplan` locally, posts adds, changes, destroys and the hourly cost delta in the PR,
and applies only that saved plan.

## Consequences

- CI has exactly one AWS role, scoped to ECR push from `refs/heads/main`.
- Plans depend on the operator. A two-person team would want an apply gate with a second
  approver, for example Atlantis or HCP Terraform with a private agent inside the VPC.
