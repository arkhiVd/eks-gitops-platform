# eks-gitops-platform: tasks

## Current phase: 3, platform bootstrap

- [x] LBC, Karpenter IAM and Argo CD applied; re-plan empty
- [x] All Applications Synced and Healthy, evidence in `docs/evidence/platform.md`
- [x] Smoke Ingress got an ALB (HTTP 200) and the ALB was removed on delete
- [x] Karpenter launched and consolidated a `c7i-flex.large` burst node
- [ ] Merge, then `terraform apply` with `gitops_revision=main` so root tracks `main`
  - Validation: Applications show a `main` revision and stay Synced and Healthy

## Completed

- [x] 2026-11-11 Phase 0 guardrail docs, approved by Aravind (PR #1)
- [x] 2026-11-11 Phase 1 bootstrap applied, 10 added, re-plan empty (PR #2)
- [x] 2026-11-11 OIDC trust proven both ways, see `docs/evidence/oidc-trust.md`
- [x] 2026-11-11 Phase 2 cluster applied, see `docs/evidence/cluster.md` (PR #3)
