# eks-gitops-platform: tasks

## Current phase: 1, bootstrap

- [x] Bootstrap stack applied
  - Validation: `terraform apply tfplan` added 10, changed 0, destroyed 0; re-plan with
    `-detailed-exitcode` returned 0 (no changes)
- [ ] OIDC trust proven (PR side done: run 42960540712, `sub` is the ID form, assume denied)
  - Acceptance criteria: `oidc-probe` on a PR fails to assume `eks-gitops-gha-ecr-push`;
    dispatched from `main` it succeeds; the recorded `sub` form is kept in the trust
    policy and the unused form is removed
  - Blockers: the `main` run needs PR #1 and this PR merged

## Completed

- [x] 2026-11-11 Phase 0 guardrail docs, approved by Aravind (PR #1)
- [x] 2026-11-11 Public repo `arkhiVd/eks-gitops-platform` created
