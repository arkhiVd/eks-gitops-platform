# 0002. EKS Pod Identity and access entries, no IRSA and no aws-auth

Status: accepted, 2026-11-11

## Context

Three in-cluster controllers call AWS: the Load Balancer Controller, Karpenter and the EBS CSI
driver. IRSA needs an IAM OIDC provider per cluster and a trust policy per role that names
the cluster's issuer URL. The `aws-auth` ConfigMap maps IAM to Kubernetes users inside the
cluster, where a bad edit can lock everyone out.

## Decision

- Cluster access uses EKS access entries only (`authentication_mode = "API"`). The operator's
  IAM principal is the only entry, with `AmazonEKSClusterAdminPolicy`.
- Every controller role trusts `pods.eks.amazonaws.com` and is bound to its service account by
  an `aws_eks_pod_identity_association`. `enable_irsa = false`, so no IAM OIDC provider exists
  for the cluster.
- The node role gets only the managed worker, CNI, ECR read and SSM policies. Nodes use
  IMDSv2 with a hop limit of 1, so pods cannot borrow the node role.

## Consequences

- Role trust policies do not change when a cluster is rebuilt.
- Access lives in the EKS API, where `aws eks list-access-entries` shows all of it.
- The hop limit of 1 also blocks pods from reading region and VPC ID from IMDS. The LBC Helm
  release sets `region` and `vpcId` explicitly for that reason.
