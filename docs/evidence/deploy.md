# Evidence: application and GitOps deploy (Phase 4)

Captured 2026-11-13/14.

## Pipeline: merge to running pods, no human kubectl

| Step | Proof |
|---|---|
| PR #5 merged to `main` (`c87f2c5`) | [PR #5](https://github.com/arkhiVd/eks-gitops-platform/pull/5) |
| `app` run on main: test, 3 × build + trivy + push, bump | [run 43482294409](https://github.com/arkhiVd/eks-gitops-platform/actions/runs/43482294409), all jobs `success` |
| CI opened the deploy PR, diff = 3 lines `newTag: unset` → `newTag: c87f2c5eabd1` | [PR #6](https://github.com/arkhiVd/eks-gitops-platform/pull/6) |
| Checks on the deploy PR: dispatched `validate` (run 43482499676) `success`; the bot-PR `pull_request` run waited for approval, was approved, then passed | PR #6 checks |
| PR #6 merged; Argo CD `chain` reached `Synced/Healthy` | 61 s after merge |

```
NAME                    STATUS    READY   IMAGE
app1-644cb5d7cc-4jkpv   Running   true    348032171026.dkr.ecr.us-east-1.amazonaws.com/eks-gitops/app1:c87f2c5eabd1
app2-65d84c4d6b-4t7gm   Running   true    348032171026.dkr.ecr.us-east-1.amazonaws.com/eks-gitops/app2:c87f2c5eabd1
fe-6bb46ffc6c-88qmg     Running   true    348032171026.dkr.ecr.us-east-1.amazonaws.com/eks-gitops/fe:c87f2c5eabd1
(2 replicas each)
```

CI holds only the ECR push role. It has no access entry and no `eks:` permission
(`docs/evidence/oidc-trust.md`).

## Through the ALB

```
GET /                FE Server Running                [200]
GET /api/hello       Hello from App1 (8081)           [200]
GET /api/fullchain   App1 -> Hello from App2 (8082)   [200]
GET /api/version     c87f2c5eabd1                     [200]
```

Host: `k8s-chain-chain-b3a1783daa-803387666.us-east-1.elb.amazonaws.com`, created by the AWS
Load Balancer Controller from `gitops/workloads/chain/ingress.yaml`.

## NetworkPolicy enforcement (VPC CNI agent)

| Path | Expected | Result |
|---|---|---|
| fe → app1:8081 | allowed | `Hello from App1 (8081)` |
| fe → app2:8082 (skipping a hop) | denied | `wget: download timed out` |
| fe → internet | denied | `wget: download timed out` |
| pod in another namespace → app2:8082 | denied | `BLOCKED` |

## Supply chain

- Base images pinned by digest; OS packages patched at build; pip and setuptools removed.
- `trivy image --severity HIGH,CRITICAL --ignore-unfixed` gates every build (exit 1 on findings).
- ECR repos are `IMMUTABLE`; a SHA tag cannot be overwritten.

## Found during the deploy

- **Untagged ECR entries, no ECR scan result.** The runner's Docker pushes an image index with
  attestation manifests, so each repo shows extra untagged entries and ECR basic scanning
  reports no status for the index. The trivy gate in CI is unaffected. Follow-up: build with
  `--provenance=false --sbom=false`.
- **All six chain pods landed on one node.** `topologySpreadConstraints` uses
  `whenUnsatisfiable: ScheduleAnyway`, which the scheduler treated as a preference. A node
  loss would take the whole chain down. Follow-up for the Phase 5 node-termination drill:
  `DoNotSchedule` for fe and app1.
