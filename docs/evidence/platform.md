# Evidence: platform bootstrap (Phase 3)

Captured 2026-11-11 after `terraform -chdir=infra apply` (32 added, 0 changed, 0 destroyed).
Re-plan with `-detailed-exitcode` returned 0.

## Argo CD owns the platform

```
NAME              SYNC     HEALTH
karpenter         Synced   Healthy
karpenter-nodes   Synced   Healthy
monitoring        Synced   Healthy
root              Synced   Healthy
storage           Synced   Healthy
```

Terraform installed only the AWS Load Balancer Controller, Argo CD and the root Application.
Everything in the table above came from `gitops/`.

### First fix shipped through git

The first `monitoring` sync OOMKilled Grafana at a 256Mi limit (`grafana OOMKilled 3`). The fix
was a commit to `gitops/platform/monitoring/values.yaml` (512Mi), not a `kubectl edit`. The
initial sync operation was stuck waiting for the crashing Deployment to become healthy, so it
was terminated (`status.operationState.phase=Terminating`, what `argocd app terminate-op`
does). Auto-sync then applied the new revision:

```
{"limits":{"memory":"512Mi"},"requests":{"cpu":"100m","memory":"256Mi"}}
```

Prometheus has a 10Gi PVC bound on the `gp3` StorageClass from `gitops/platform/storage`.

## ALB through the Load Balancer Controller

A smoke Ingress in namespace `smoke` (deleted after the test):

```
k8s-smoke-web-1748a5f5cf    application    internet-facing    active
curl http://k8s-smoke-web-1748a5f5cf-824165854.us-east-1.elb.amazonaws.com/ -> 200
```

After `kubectl delete ns smoke`, `aws elbv2 describe-load-balancers` returned nothing: the
controller removed the ALB it created.

## Karpenter on a FREE plan account

Three pods requesting 500m CPU each with `nodeSelector: node-role=burst`:

```
NAME          TYPE             CAPACITY    ZONE         READY
burst-h8j4c   c7i-flex.large   on-demand   us-east-1a   True
```

Karpenter picked the cheaper of the two allowed free-plan types and the node was Ready about
80 seconds after the pods were created. After the namespace was deleted, Karpenter logged
`disrupting node(s)`, `tainted node`, `deleted node`, `deleted nodeclaim`, and EC2 showed
`i-0f530c82ece7d80c1 terminated` with tag `project=eks-gitops-platform`.
