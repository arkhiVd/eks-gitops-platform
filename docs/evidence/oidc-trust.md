# Evidence: CI trust boundary (Phase 1)

Claim: GitHub Actions can assume `eks-gitops-gha-ecr-push` only from `main` of this repo,
and that role has no EKS, S3 or IAM permission.

## Subject claim form

This repo's OIDC tokens carry the immutable-ID subject form. Recorded by `oidc-probe`:

| Run | Context | `sub` | Assume |
|---|---|---|---|
| [42960540712](https://github.com/arkhiVd/eks-gitops-platform/actions/runs/42960540712) | PR #2 | `repo:arkhiVd@95763443/eks-gitops-platform@1453514477:pull_request` | failure (`Not authorized to perform sts:AssumeRoleWithWebIdentity`) |
| [42966410895](https://github.com/arkhiVd/eks-gitops-platform/actions/runs/42966410895) | dispatch on `main` | `repo:arkhiVd@95763443/eks-gitops-platform@1453514477:ref:refs/heads/main` | success, `arn:aws:sts::348032171026:assumed-role/eks-gitops-gha-ecr-push/GitHubActions` |

The trust policy accepts only the second subject (`bootstrap/github_oidc.tf`). A repo
recreated under the same name gets a new repo ID, so it cannot assume this role.

## Role permissions

`ecr:GetAuthorizationToken` on `*` (the action has no resource-level form) and push actions on
`arn:aws:ecr:us-east-1:348032171026:repository/eks-gitops/*`. Nothing else. Check:

```bash
aws iam get-role-policy --role-name eks-gitops-gha-ecr-push --policy-name ecr-push-project-repos
aws iam list-attached-role-policies --role-name eks-gitops-gha-ecr-push   # empty
```
