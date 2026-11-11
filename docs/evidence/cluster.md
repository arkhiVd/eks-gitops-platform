# Evidence: network and cluster (Phase 2)

Captured 2026-11-11 after `terraform -chdir=infra apply`.

## Apply history

| Apply | Result |
|---|---|
| 1 | 54 planned. Cluster, VPC, IAM, KMS, 2 add-ons created. Node group `CREATE_FAILED`: `The specified instance type is not eligible for Free Tier` (t3.medium). The FREE plan allows `eks:CreateCluster` but launches only free-tier-eligible instance types. |
| 2 | Nodes switched to `m7i-flex.large`. 5 added, 0 changed, 1 destroyed (the tainted node group). |
| Re-plan | `terraform plan -detailed-exitcode` returned 0 |

## Nodes

```
NAME                           STATUS   VERSION               INTERNAL-IP    OS-IMAGE                        CONTAINER-RUNTIME
ip-10-40-28-129.ec2.internal   Ready    v1.37.1-eks-8418f54   10.40.28.129   Amazon Linux 2023.12.20261102   containerd://2.3.7+unknown
ip-10-40-46-61.ec2.internal    Ready    v1.37.1-eks-8418f54   10.40.46.61    Amazon Linux 2023.12.20261102   containerd://2.3.7+unknown
```

Instances: `m7i-flex.large`, IMDS `HttpTokens=required`, hop limit `1`, no key pair.

## Access

- `kubectl -n kube-system get cm aws-auth` → `configmaps "aws-auth" not found`
- `aws eks list-access-entries` → the EKS service-linked role, the node group role, and
  `user/admin-gbngg`. No CI principal.
- `publicAccessCidrs` = `149.88.103.45/32`, `endpointPrivateAccess` = `True`

## Network exposure

Inbound rules with `0.0.0.0/0` on the node security group (`sg-0b799d817487ef547`, the only SG
on the nodes) and on the EKS cluster security group: none.

## Add-ons and Pod Identity

`vpc-cni`, `coredns`, `kube-proxy`, `eks-pod-identity-agent`, `aws-ebs-csi-driver`,
`metrics-server`, all Running. One Pod Identity association: `kube-system/ebs-csi-controller-sa`.
