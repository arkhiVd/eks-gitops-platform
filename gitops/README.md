# gitops

Everything Argo CD syncs. Terraform creates one Application, `root`, that points at
`gitops/apps/`. Each file there is an Application for one component. Sync waves set the order.

| Wave | Application | Source |
|---|---|---|
| -2 | `storage` | `gitops/platform/storage` (gp3 default StorageClass) |
| -1 | `karpenter` | Helm `karpenter` 1.15.1 from `public.ecr.aws/karpenter` |
| 0 | `karpenter-nodes` | `gitops/platform/karpenter-nodes` (EC2NodeClass, NodePool) |
| 1 | `monitoring` | Helm `kube-prometheus-stack` 93.2.0, values in `gitops/platform/monitoring` |

Change the cluster by changing files here and merging a PR. Manual `kubectl` edits to these
objects are reverted by self-heal.
