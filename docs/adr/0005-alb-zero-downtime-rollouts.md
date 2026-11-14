# 0005. ALB with IP targets, readiness gates and a drain longer than deregistration

Status: accepted, 2026-11-14

## Context

The free plan blocks Network Load Balancers, so the edge is an ALB created by the AWS Load
Balancer Controller from an `Ingress`. With `target-type: ip` the ALB sends traffic straight
to pod IPs. Kubernetes and the ALB do not agree on when a pod starts or stops serving. A
rolling update dropped 2 of 71 requests during the rollback drill.

## Decision

- The `chain` namespace carries `elbv2.k8s.aws/pod-readiness-gate-inject: enabled`. A new pod
  is not Ready until its ALB target is healthy, so the rollout cannot outrun the ALB.
- Deregistration delay is 15 s. `fe` sleeps 25 s in `preStop` and has a 45 s grace period, so
  it keeps serving until the ALB has stopped sending to it.
- Topology spread uses `DoNotSchedule` with `matchLabelKeys: [pod-template-hash]`, so spread
  is counted per ReplicaSet and new pods do not stack on one node during a rollout.

## Consequences

Measured under 50 req/s while every pod was replaced (`docs/evidence/drills.md`):

| Change | Failed requests |
|---|---|
| None | 2 of 71 |
| Readiness gates, 15 s preStop | 14 of 7,496 |
| 25 s preStop, spread per ReplicaSet | 0 of 9,000 |

A 15 s preStop equal to the deregistration delay was still too short. The drain has to be
longer than the delay. The cost is slower rollouts, about 25 s extra per pod.
