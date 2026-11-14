# eks-gitops-platform: tasks

## Current phase: 7, teardown (done 2026-11-14, evidence in `docs/evidence/teardown.md`)

- [x] Ingress, Prometheus PVC, NodePool removed through Argo CD before Terraform
- [x] `infra/` destroyed from a saved plan: 92 destroyed
- [x] `bootstrap/` destroyed from a saved plan: 10 destroyed, state bucket emptied by `force_destroy`
- [x] Sweep: no cluster, ALB, instance, volume, ENI, VPC, ECR repo, queue, role or bucket of ours left
- [ ] Cost Explorer shows $0 for this project from 2026-11-15
- [ ] Resume bullet: proposed to Aravind outside the repo; Aravind decides

## Completed

- [x] 2026-11-11 Phase 0 guardrail docs, approved by Aravind (PR #1)
- [x] 2026-11-11 Phase 1 bootstrap applied, 10 added, re-plan empty (PR #2)
- [x] 2026-11-11 OIDC trust proven both ways, see `docs/evidence/oidc-trust.md`
- [x] 2026-11-11 Phase 2 cluster applied, see `docs/evidence/cluster.md` (PR #3)
- [x] 2026-11-11 Phase 3 platform applied, see `docs/evidence/platform.md` (PR #4)
- [x] 2026-11-14 Phase 4 pipeline deploy, see `docs/evidence/deploy.md` (PRs #5, #6, #7)
- [x] 2026-11-14 Phase 5 drills, see `docs/evidence/drills.md` (PRs #8 to #13)
- [x] 2026-11-14 Phase 6 write-up: README, ADRs, screenshots (PR #14)
