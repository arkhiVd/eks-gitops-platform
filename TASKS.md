# eks-gitops-platform: tasks

## Current phase: 4, application and CI/CD

- [x] Services ported, 5 pytest tests, ruff clean; images non-root, read-only, 0 fixable HIGH/CRITICAL
- [x] ECR repos (immutable, scan on push) and VPC CNI network policy applied; re-plan empty
- [x] Chain manifests: restricted PSA, HPA, PDBs, ALB Ingress, default-deny NetworkPolicies
- [x] Repo setting: Actions may open PRs (Aravind approved 2026-11-13); default token stays read
- [ ] Merge, CI pushes images and opens the tag-bump PR, merge it, Argo deploys
  - Validation: `curl http://<alb>/api/fullchain` returns the full chain; pods run the SHA tag

## Completed

- [x] 2026-11-11 Phase 0 guardrail docs, approved by Aravind (PR #1)
- [x] 2026-11-11 Phase 1 bootstrap applied, 10 added, re-plan empty (PR #2)
- [x] 2026-11-11 OIDC trust proven both ways, see `docs/evidence/oidc-trust.md`
- [x] 2026-11-11 Phase 2 cluster applied, see `docs/evidence/cluster.md` (PR #3)
- [x] 2026-11-11 Phase 3 platform applied, see `docs/evidence/platform.md` (PR #4)
