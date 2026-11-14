# 0004. Managed node group for system pods, Karpenter for burst

Status: accepted, 2026-11-11

## Context

The free plan has an 8 vCPU on-demand quota and launches only free-tier-eligible instance
types. The first node group on `t3.medium` failed for that reason. Karpenter cannot run on
nodes it manages, and Argo CD, Prometheus and the controllers should not move on every
consolidation.

## Decision

- One EKS managed node group of 2 × `m7i-flex.large` (4 vCPU), labelled `node-role=system`.
  Karpenter's controller pins to it with a nodeSelector.
- One Karpenter `NodePool` named `burst`, on-demand `m7i-flex.large` or `c7i-flex.large` only,
  capped at 4 vCPU,
  with consolidation `WhenEmptyOrUnderutilized` after 1 minute and `expireAfter` 24 h.
- Karpenter's interruption queue (SQS) is wired. The NodePool has no spot, so the queue
  only carries scheduled maintenance and instance state events.

## Consequences

- Managed nodes plus the Karpenter cap equal the quota of 8 vCPU, so a runaway scale-out
  stops at the NodePool limit instead of at an EC2 error.
- In the node-loss drill Karpenter launched a node in the AZ of Prometheus' EBS volume and
  Prometheus was back in 75 s, before the node group's replacement joined at 99 s.
- `m7i-flex.large` gives 8 GiB per node, which is enough for kube-prometheus-stack with a
  2-day retention and a 512Mi Grafana limit.
