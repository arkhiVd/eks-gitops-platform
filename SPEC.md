# eks-gitops-platform: specification

## Problem

`boutique-platform` proved a hardened Kubernetes platform on k3s. It ruled EKS out because
the control plane alone costs $73/month, which did not fit a six-month free-plan budget.
That changed on 2026-11-11. The free-plan account has $131.69 of credit left and closes on
2026-11-20. The credit is lost either way, so for nine days EKS costs nothing out of pocket.

This repo uses that window to build the EKS-specific half of a DevOps job description that
k3s cannot show: managed control plane, EKS access entries, Pod Identity, the AWS Load
Balancer Controller, Karpenter, and a pull-based GitOps deploy where CI never holds cluster
credentials. The live cluster is temporary. The durable artifact is this repo: Terraform,
manifests, CI, and an evidence pack that lets an interviewer check each claim.

## Users

| User | Constraint |
|---|---|
| Aravind (operator) | One person, 9 days, $131.69 of credit, 8 vCPU on-demand quota, runs every `terraform apply` himself |
| Recruiter or interviewer | Reads the repo and `docs/evidence/`; every claim links to command output or a screenshot |
| Developer persona | Pushes app code; sees it running after a merged PR with no `kubectl` access of their own |

## Account facts (live evidence, 2026-11-11)

| Fact | Value | Consequence |
|---|---|---|
| Account, plan | `348032171026`, FREE, ACTIVE | all cost is credit until expiry |
| Credit left | $131.69 | hard ceiling for the whole build |
| Plan expires | 2026-11-20 16:23 UTC | teardown to $0 finishes by 2026-11-19 |
| On-demand vCPU quota | 8 | managed nodes plus Karpenter nodes together stay at or under 8 vCPU |
| Network Load Balancer | blocked account-wide | edge is an ALB; no Service `type: LoadBalancer` with NLB |
| NAT gateways | none, $0.045/h each | nodes run in public subnets with locked-down security groups |
| Route 53 zones, ACM certs | none | the app is served over HTTP on the ALB DNS name |
| EKS clusters, IAM OIDC providers, ECR repos, budgets | none | clean start; bootstrap creates the GitHub OIDC provider and a budget |
| Pre-existing bucket `test-debzm` | not ours | never touched, never deleted |
| Region | `us-east-1` | cheapest prices, matches earlier projects |

## Required behavior

**Infrastructure (Terraform)**
- `bootstrap/` (local state) creates an S3 state bucket (versioned, SSE, public access
  blocked), the GitHub Actions OIDC provider, a read-only plan role, an ECR push role scoped
  to this repo's `main` branch, and a $130 budget with alerts at 25/50/75/90% of actual spend.
- `infra/` (S3 backend with native lockfile) creates a VPC over 3 AZs with public subnets and
  no NAT, and an EKS 1.37 cluster with one managed node group of 2 × `t3.medium`.
- Cluster access uses EKS access entries only. No `aws-auth` ConfigMap.
- The public API endpoint allows only the operator's CIDR (`var.operator_cidrs`).
- Core add-ons are EKS-managed: `vpc-cni`, `coredns`, `kube-proxy`, `eks-pod-identity-agent`,
  `aws-ebs-csi-driver`, `metrics-server`.
- Every in-cluster AWS permission uses EKS Pod Identity. No node-role wildcards and no
  long-lived keys.
- Nodes have no SSH key and no inbound rule from `0.0.0.0/0`. Shell access, if ever needed,
  goes through SSM Session Manager.
- Control plane `audit` logs go to CloudWatch with 1-day retention.

**Platform (Argo CD, app-of-apps)**
- Terraform installs only the AWS Load Balancer Controller and Argo CD, then one root
  `Application` pointing at `gitops/`. Argo CD owns everything else.
- Argo CD deploys Karpenter (`EC2NodeClass` plus a `NodePool` capped at 4 vCPU), kube-prometheus-stack,
  and the app. Every Application has automated sync with prune and self-heal on.
- Drift is corrected. A manual `kubectl edit` on a managed Deployment reverts within one sync.

**Application (`app/`)**
- The three services from `nginx-nlb-microservice-chain` (nginx `fe`, Python `app1` and
  `app2`) run as containers: `fe /api/*` → `app1` → `app2`.
- Each container runs as non-root with a read-only root filesystem, drops all capabilities,
  and sets requests, limits, liveness and readiness probes.
- `app1` has an HPA on CPU. `fe` has a PodDisruptionBudget.
- One internet-facing ALB, created by an `Ingress`, routes `/` to `fe`.

**CI/CD (GitHub Actions)**
- On every PR: `terraform fmt`/`validate`, `tflint`, `checkov`, `actionlint`, `kubeconform`,
  `gitleaks`, app unit tests, image build and `trivy image` scan.
- On merge to `main`: build images, push to ECR tagged with the commit SHA through the OIDC
  push role, then open a PR that bumps the image tag in `gitops/`. A human merges it and
  Argo CD rolls it out.
- CI never has a kubeconfig or any EKS permission.
- Rollback is `git revert` of the tag-bump commit; Argo CD rolls the old image back.

## Architecture and data flow

```
dev push ──> GitHub Actions ──(OIDC: ecr push role)──> ECR
                  │
                  └── opens PR "bump image tag" in gitops/
                                    │ human merge
                                    v
Argo CD (in cluster) ──pulls── github.com/arkhiVd/eks-gitops-platform (public)
      │
      ├── platform: Karpenter, kube-prometheus-stack
      └── apps: fe, app1, app2, Ingress
                                    │
internet ──HTTP──> ALB (made by AWS LBC) ──> fe pods ──> app1 ──> app2
```

- State: `bootstrap/` local state, kept out of git. `infra/` state lives in the bootstrap
  bucket with `use_lockfile = true`.
- Argo CD reads this public repo anonymously. No repo credential in the cluster.
- Grafana and the Argo CD UI are reached with `kubectl port-forward`, not exposed on the ALB.

## Security and privacy

- Trust boundaries: GitHub to AWS through OIDC only. The plan role is read-only. The push role
  can push only to this repo's ECR repositories and only from `refs/heads/main`.
- Cluster admin: the operator's IAM principal through an access entry with
  `AmazonEKSClusterAdminPolicy`. No other human or CI principal.
- Pod Identity associations: LBC, Karpenter, EBS CSI, each with its own role.
- Secrets: none in git. The Argo CD admin password is read once from its generated secret,
  never stored in the repo.
- Scans: `gitleaks` (CI and local), `checkov` and `trivy config` on Terraform, `trivy image`
  on every built image, CRITICAL findings fail the build.
- Never committed: `*.tfstate*`, `*.tfvars`, `.terraform/`, kubeconfigs, `.env`.

## Pinned versions

| Thing | Version | Verified on |
|---|---|---|
| Terraform | 1.15.9 | 2026-11-11 |
| AWS provider | `~> 6.72` (6.72.0) | 2026-11-11 |
| Helm provider | `~> 3.3` (3.3.0) | 2026-11-11 |
| `terraform-aws-modules/vpc/aws` | 6.7.3 | 2026-11-11 |
| `terraform-aws-modules/eks/aws` | 21.29.0 | 2026-11-11 |
| EKS Kubernetes | 1.37 (current default, standard support) | 2026-11-11 |
| kubectl | v1.36.3 (one minor behind, inside supported skew) | 2026-11-11 |
| Helm CLI | v3.16.3 | 2026-11-11 |
| aws-load-balancer-controller chart | 3.6.2 | 2026-11-11 |
| argo-cd chart | 10.17.2 (Argo CD v3.6.1) | 2026-11-11 |
| karpenter chart (OCI) | 1.15.1 | 2026-11-11 |
| kube-prometheus-stack chart | 93.2.0 | 2026-11-11 |
| tflint / checkov / trivy | 0.60.0 / 3.3.13 / 0.69.3 | 2026-11-11 |
| actionlint / gitleaks | 1.7.11 / 8.30.1 | 2026-11-11 |
| EKS add-on versions | resolved with `aws eks describe-addon-versions` in Phase 2 | |
| Python and nginx base images | resolved in Phase 4 | |

## Cost and limits

Steady state, `us-east-1`, cluster up:

| Item | $/hour |
|---|---|
| EKS control plane (standard support) | 0.100 |
| 2 × t3.medium on-demand | 0.083 |
| ALB hour plus light LCU | 0.030 |
| Public IPv4, about 4 addresses | 0.020 |
| EBS gp3, about 60 GB | 0.007 |
| **Total** | **about 0.24, so about $5.80/day** |

Planned live window 2026-11-13 to 2026-11-19 is about $40. Karpenter bursts, ECR, CloudWatch
and S3 add a few dollars. Target total spend is $50 or less, leaving credit for other labs.

- Teardown expectation: destroy everything, including `bootstrap/`, by 2026-11-19. After the
  plan expires the account closes and nothing can be kept there.
- Capacity: managed nodes use 4 vCPU and the Karpenter `NodePool` limit is 4 vCPU, so the
  quota of 8 can never be exceeded.

## Non-goals

- TLS and a real hostname. No Route 53 zone here; cross-account delegation is out of scope.
- Private subnets with NAT, VPC endpoints, multi-cluster, service mesh.
- Rebuilding what `boutique-platform` already proves: WAF, SLO burn alerts, Loki, Tempo,
  supply-chain signing.
- A CI `terraform apply` job. Apply stays a human action from the operator's machine.
- Keeping anything running after 2026-11-19.

## Acceptance criteria

- [ ] Bootstrap applies cleanly and a second `terraform plan` is empty. Check: `terraform -chdir=bootstrap plan -detailed-exitcode` returns 0
- [ ] Cluster is up with 2 Ready nodes on 1.37. Check: `kubectl get nodes -o wide`
- [ ] No `aws-auth` ConfigMap is used and access is via access entries. Check: `aws eks list-access-entries --cluster-name <name>`
- [ ] API endpoint rejects other CIDRs. Check: `aws eks describe-cluster --query cluster.resourcesVpcConfig.publicAccessCidrs`
- [ ] Every Argo CD Application is `Synced` and `Healthy`. Check: `kubectl -n argocd get applications`
- [ ] `curl http://<alb-dns>/api/fullchain` returns `App1 -> Hello from App2 (8082)`. Check: pasted output
- [ ] A merged app change reaches the cluster with no human `kubectl`. Check: PR links plus `kubectl get deploy -o jsonpath` showing the new SHA tag
- [ ] Rollback by `git revert` restores the old tag. Check: before and after output
- [ ] Drift self-heals. Check: `kubectl scale` on a managed Deployment, then output showing Argo CD reverting it
- [ ] Karpenter adds a node under load and removes it after. Check: `kubectl get nodeclaims` during and after the load test
- [ ] HPA scales `app1` under load. Check: `kubectl get hpa -w` output
- [ ] Grafana shows cluster and app metrics. Check: screenshot
- [ ] CI never touches the cluster. Check: the IAM policies of both CI roles, pasted, contain no `eks:` action
- [ ] Teardown leaves no billable resource. Check: tagged-resource query and `aws eks list-clusters` both empty

## Unresolved questions

- Does the FREE plan allow `CreateCluster`? Nothing here says it is blocked, but NLB was. The
  first Phase 2 apply answers it. If it is blocked, fall back to the kubeadm-on-EC2 lab.
- Operator CIDR for the API endpoint. A home IP changes and ProtonVPN changes it too. Phase 2
  takes it as a variable; widening it is a one-line apply.
