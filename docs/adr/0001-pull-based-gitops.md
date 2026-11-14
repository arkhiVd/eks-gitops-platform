# 0001. Pull-based GitOps, CI never holds cluster credentials

Status: accepted, 2026-11-11

## Context

A push pipeline (`kubectl apply` or `helm upgrade` from GitHub Actions) needs a kubeconfig
or an IAM role with EKS access in CI. Anyone who can change a workflow file can then change
the cluster. The point of this repo is to show a deploy path where that is impossible.

## Decision

Argo CD runs in the cluster and pulls `gitops/` from this public repo anonymously. CI builds
images, pushes them to ECR through one OIDC role (`eks-gitops-gha-ecr-push`), and opens a PR
that bumps the image tag in `gitops/workloads/chain/kustomization.yaml`. A human merges the
PR and Argo CD rolls it out. Terraform installs only the AWS Load Balancer Controller, Argo CD
and one root `Application`. Argo CD owns everything else through app-of-apps with sync waves.

## Consequences

- The CI role has no `eks:` action and no access entry. Checked in `docs/evidence/oidc-trust.md`.
- Every deploy and every rollback is a git commit. Rollback is `git revert` of the tag-bump
  commit, measured at 26 s to the old version in `docs/evidence/drills.md`.
- Manual changes are undone. A `kubectl scale` and a deleted Service were reverted in 10 s.
- A human merge sits between build and deploy. That is slower than auto-deploy and is on
  purpose here. Argo CD Image Updater could remove it later.
- PRs opened by `GITHUB_TOKEN` do not trigger `pull_request` workflows on their own, so the
  app workflow dispatches `validate.yml` on the deploy branch.
