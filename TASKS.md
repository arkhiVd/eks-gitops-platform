# eks-gitops-platform: tasks

## Current phase: 5, operations drills (done, evidence in `docs/evidence/drills.md`)

- [x] Drift self-heal: scale + deleted Service reverted in 10 s
- [x] HPA: app1 2 → 6 under 665 req/s, back to 2 after stabilization
- [x] Rollback via `git revert` (PR #10), old version live in 26 s
- [x] Zero-downtime rollouts: 0 / 9,000 failed after PRs #11 and #12
- [x] Node loss: Karpenter replaced capacity in the volume's AZ; 0.09% errors
- [ ] Grafana chain dashboard, deferred to Phase 6

## Completed

- [x] 2026-11-11 Phase 0 guardrail docs, approved by Aravind (PR #1)
- [x] 2026-11-11 Phase 1 bootstrap applied, 10 added, re-plan empty (PR #2)
- [x] 2026-11-11 OIDC trust proven both ways, see `docs/evidence/oidc-trust.md`
- [x] 2026-11-11 Phase 2 cluster applied, see `docs/evidence/cluster.md` (PR #3)
- [x] 2026-11-11 Phase 3 platform applied, see `docs/evidence/platform.md` (PR #4)
- [x] 2026-11-14 Phase 4 pipeline deploy, see `docs/evidence/deploy.md` (PRs #5, #6, #7)
