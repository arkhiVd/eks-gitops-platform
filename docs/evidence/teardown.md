# Evidence: teardown to $0 (Phase 7)

Captured 2026-11-14, five days before the deadline. All times UTC.

## Order and why

Controllers in the cluster own AWS resources that Terraform never saw: the ALB (Load Balancer
Controller), the Prometheus EBS volume (EBS CSI driver) and any Karpenter nodes. If Terraform
deleted the cluster first, those would be orphaned and keep billing, and the ALB's ENIs and
security group would block the VPC delete. So the cluster cleans up its own resources first.

| Step | Command | Result |
|---|---|---|
| 1 | `kubectl -n argocd patch application root` (remove `automated`) | root stops recreating child Applications |
| 2 | `kubectl -n argocd delete application chain` | Argo CD's resource finalizer deleted the Ingress; ALB gone at 09:44:46, 2 s after the delete returned |
| 3 | `kubectl -n argocd delete application monitoring`, then `kubectl -n monitoring delete pvc --all` | StatefulSet PVCs outlive the StatefulSet, so the claim was deleted by hand; the 10 GiB gp3 volume was gone at 09:45:33 |
| 4 | `kubectl -n argocd delete application karpenter-nodes` | NodePool `burst` and EC2NodeClass `default` deleted while Karpenter still ran to clear their finalizers; 0 Karpenter nodes existed |
| 5 | `kubectl -n argocd delete application karpenter storage` | only Argo CD and `kube-system` pods left |
| 6 | `terraform -chdir=infra plan -destroy -out=tfplan`, then `apply tfplan` | `Plan: 0 to add, 0 to change, 92 to destroy.` 09:47:36 to 09:59:39, `Resources: 0 added, 0 changed, 92 destroyed.` |
| 7 | `terraform -chdir=bootstrap apply -var state_bucket_force_destroy=true` | 1 changed in place, so the versioned state bucket (44 versions, 19 delete markers) can be deleted |
| 8 | `terraform -chdir=bootstrap plan -destroy -var state_bucket_force_destroy=true -out=tfplan`, then `apply tfplan` | `Resources: 0 added, 0 changed, 10 destroyed.` The same 10 resources Phase 1 created |

Both destroy plans were read before applying: destroys only, no creates, updates or replaces.
The infra plan covered the EKS cluster and node group, 6 add-ons, VPC, subnets and routes,
IAM roles and policies, Pod Identity associations, 3 ECR repositories with their images
(`force_delete`), the Karpenter SQS queue and EventBridge rules, the KMS key, the audit log
group and the 3 Helm releases.

## Sweep after destroy

```
## eks clusters             (none)
## load balancers           (none)
## target groups            (none)
## instances (not terminated) (none)
## volumes us-east-1        (none)
## snapshots                (none)
## elastic IPs              (none)
## ENIs                     (none)
## VPCs (non-default)       (none)
## ECR repos                (none)
## SQS                      None
## event rules              (none matching karpenter|gitops)
## IAM roles, policies, instance profiles (none matching gitops|karpenter|lbc|ebs-csi)
## OIDC providers           (none)
## log groups               (none matching eks-gitops)
## S3 buckets               (only a pre-existing bucket that is not this project's)
```

The tag query `aws resourcegroupstaggingapi get-resources --tag-filters
Key=project,Values=eks-gitops-platform` still listed 6 ARNs. Each was checked directly:

| ARN | Direct check | Billable |
|---|---|---|
| security group `sg-08de1992818fd5895` | `InvalidGroup.NotFound` | no, stale index entry |
| volume `vol-0dc396fa180407757` | `InvalidVolume.NotFound` | no, stale index entry |
| Pod Identity association `a-w6uyqqpv3ylzqygnj` | `No cluster found for name: eks-gitops` | no, stale index entry |
| 2 EC2 fleets | type `instant`: the request records Karpenter's `CreateFleet` calls leave behind, no instances | no |
| KMS key `f6420b31-…` | `PendingDeletion`, deletes 2026-12-14 (30-day window set by the EKS module) | no, AWS does not bill keys pending deletion |

Resources without the `project=eks-gitops-platform` tag were not touched.

## Still to check

- [ ] Cost Explorer daily spend for this project reaches $0 from 2026-11-15. The 2026-11-14
  line covers about 10 cluster hours and had not posted when this file was written.
