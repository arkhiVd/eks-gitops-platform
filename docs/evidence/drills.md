# Evidence: operations drills (Phase 5)

Run 2026-11-14 on the live cluster. Load came from `fortio/fortio:1.76.0` in a throwaway
`smoke` namespace, hitting `/api/fullchain` through the ALB.

## 1. Drift self-heal

| Injected (18:38:54 UTC) | Healed |
|---|---|
| `kubectl scale deploy fe --replicas=5` | back to 2 |
| `kubectl delete svc app2` | recreated (`Service/app2 Synced service/app2 created`) |

Both corrected **10 s** later by an automated sync (`initiatedBy: {"automated":true}`).

## 2. HPA under load

fortio, 32 connections, unthrottled, 4 minutes: 161,615 calls at 665 req/s.

```
18:47:22  cpu 2%/60%    replicas=2
18:47:58  cpu 660%/60%  replicas=2 → 4 → 6   (SuccessfulRescale ×2, 15 s apart)
18:52:09  cpu 2%/60%    replicas=6          (load ended)
18:56:54  replicas=2                        (scale-down after the 5-minute stabilization window)
```

Result codes: 200 × 161,538, 502 × 29, 504 × 41, client errors × 7 (0.048% total). app1 hit
its max of 6 at 200–370% of request, so app1's CPU request (50m) is the ceiling at this load.
Karpenter was not needed: six app1 pods fit on the two managed nodes. Karpenter scale-out and
consolidation are shown in `platform.md`.

## 3. Rollback by `git revert`, then zero-downtime fixes

Two pipeline deploys existed: `c87f2c5eabd1` (PR #6) and `9e0ba8c8f02b` (PR #9, 17 s from
merge to the new `/api/version`). PR #10 is `git revert -m 1` of the #9 merge: a 3-line tag
change. After merge, `/api/version` returned `c87f2c5eabd1` within 26 s.

The rollback dropped requests, which led to two fixes, each measured under the same load
(fortio, 8 connections, 50 req/s) while every chain pod was replaced:

| Rollout | Change | Failed / total |
|---|---|---|
| PR #10 (light curl loop) | baseline | 2 / 71 (one 502, one timeout) |
| PR #11 | LBC pod readiness gates; `preStop` = deregistration delay (15 s) | 14 / 7,496 |
| PR #12 | `preStop` 25 s > 15 s delay; `matchLabelKeys: [pod-template-hash]` | **0 / 9,000** |

Readiness gates on fe pods: `target-health.elbv2.k8s.aws/k8s-chain-fe-cd9d32867a`.

PR #11 also showed pods stacking on one node mid-rollout: the old ReplicaSet's pods share
`app=<name>` and counted in the spread skew. `matchLabelKeys` fixed it; after #12 each
service has one pod on each node.

## 4. Node loss under load

Terminated `i-057f2aee7121b4955` (us-east-1b), the node running all of Argo CD, the Prometheus
operator and Prometheus (EBS volume in us-east-1b), plus one replica of each chain service.
fortio ran 6 minutes at 50 req/s from the surviving node.

| Time | Event |
|---|---|
| T+0 | `terminate-instances` → `shutting-down` |
| +3 s | node `NotReady`; pods evicted; Prometheus `Pending` (its volume is AZ-bound) |
| +3 s | Karpenter NodeClaim `c7i-flex.large` **in us-east-1b**, the volume's AZ |
| +50 s | Karpenter node Ready; chain 6 Ready, replacements starting |
| +75 s | Prometheus Running on the Karpenter node; old node object gone |
| +99 s | managed node group's replacement `m7i-flex.large` (us-east-1b) Ready |
| +124 s | chain 9/9 Ready (surge), then settles at 6/6 spread across nodes |
| +171 s | Karpenter consolidates its burst node away; back to 2 managed nodes |

Traffic: 18,000 calls, 200 × 17,984, 502 × 9, 504 × 5, client errors × 2 (**0.09%**). The
failures cluster in the seconds after termination, when the ALB still routed to the dead fe
target until its health check (10 s interval, 2 failures) took it out. The GitOps control
plane was down during this window and the chain kept serving, because Argo CD is not in the
request path.

## Supply chain follow-up from Phase 4

PR #8 builds with `--provenance=false --sbom=false`. ECR now stores a single
`application/vnd.docker.distribution.manifest.v2+json` per tag and basic scanning completes:
`9e0ba8c8f02b` app1 shows HIGH × 2, both glibc 2.41 (CVE-2026-5435, CVE-2026-19499) with no
Debian fix yet, which is why the CI trivy gate (`--ignore-unfixed`) passes.

## Not done

- A Grafana dashboard for the chain (ROADMAP Phase 5). The services expose no metrics of their
  own; deferred to Phase 6 with screenshots of the kube-prometheus-stack dashboards.
- Lowering the ALB health check interval to cut node-loss errors further.
