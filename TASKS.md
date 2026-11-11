# eks-gitops-platform: tasks

## Current phase: 2, network and cluster

- [x] VPC and EKS 1.37 cluster applied, evidence in `docs/evidence/cluster.md`
  - Scope: `infra/` (VPC, EKS, managed node group, add-ons, EBS CSI Pod Identity role)
  - Acceptance criteria: 2 Ready nodes on v1.37; re-plan empty; public access CIDRs equal
    `var.operator_cidrs`; access entries list only the operator; no `aws-auth` ConfigMap
  - Automated validation: local gate in `AGENTS.md`, CI on the PR
  - Manual validation: `kubectl get nodes -o wide`, `aws eks list-access-entries`
  - Result: FREE plan allows EKS; t3.medium was refused, nodes are `m7i-flex.large`
- [ ] PR merged after CI and fresh-context review

## Completed

- [x] 2026-11-11 Phase 0 guardrail docs, approved by Aravind (PR #1)
- [x] 2026-11-11 Phase 1 bootstrap applied, 10 added, re-plan empty (PR #2)
- [x] 2026-11-11 OIDC trust proven both ways, see `docs/evidence/oidc-trust.md`
