# eks-gitops-platform: roadmap

Status: Phase 4 in progress (2026-11-13). Phases 0 to 3 merged.

Hard deadline: Phase 7 teardown finishes by 2026-11-19. The free plan expires
2026-11-20 16:23 UTC. If the schedule slips, cut Phase 5 or 6, never Phase 7.

Every phase is one PR. Change class for Phases 1, 2, 3 and 7 is **Risky** (IAM, network,
state, cost). Phases 4, 5 and 6 are **Standard** unless they touch IAM.

Apply gates. The agent runs each command from a saved plan after posting the plan summary
and cost delta. An unexpected destroy or replace stops the gate until Aravind confirms:

| Gate | Phase | Command | Cost starts |
|---|---|---|---|
| G1 | 1 | `terraform -chdir=bootstrap apply` | near $0 |
| G2 | 2 | `terraform -chdir=infra apply` (VPC plus EKS) | about $0.18/h |
| G3 | 3 | `terraform -chdir=infra apply` (LBC plus Argo CD) | ALB comes in Phase 4 |
| G4 | 7 | `terraform destroy` on `infra/` then `bootstrap/` | back to $0 |

## Phase 0: guardrails (2026-11-11)

**Outcome:** the repo has a contract that every later phase is checked against.

**Included:** `SPEC.md`, `ROADMAP.md`, `AGENTS.md`, `CLAUDE.md`, `TASKS.md`, `.gitignore`,
PR template.

**Dependencies and risks:** none; docs only.

**Exit criteria:**
- [ ] Aravind approves SPEC and ROADMAP
- [ ] GitHub repo `arkhiVd/eks-gitops-platform` exists (public)

**Validation:**
- Automated: `gitleaks detect --no-git`
- Manual: read SPEC acceptance criteria and cost table

## Phase 1: bootstrap (target 2026-11-12)

**Outcome:** remote state and GitHub OIDC trust exist, with nothing billable running.

**Included:** `bootstrap/` with local state: S3 state bucket, GitHub OIDC provider,
`gha-ecr-push` role (ECR push on this repo's repositories, `main` only). A `validate` workflow with fmt, validate, tflint, checkov, trivy,
actionlint and gitleaks, and an `oidc-probe` workflow that prints the token's `sub` claim and
tries to assume the push role.

**Dependencies and risks:** the OIDC trust `sub` claim. GitHub now emits
`repo:owner@id/repo@id:...` for some repos (seen on Clearsky). Read a real token claim from a
branch run before trusting the pattern.

**Exit criteria:**
- [ ] `bootstrap` plan is empty after apply
- [ ] `oidc-probe` from a branch fails to assume `gha-ecr-push`, and the recorded `sub` claim matches the trust policy

**Validation:**
- Automated: local gate in `AGENTS.md`, CI run on the PR
- Manual: CloudTrail `AssumeRoleWithWebIdentity` event for the plan role

**Rollback:** `terraform -chdir=bootstrap destroy` (bucket has `force_destroy` off, so empty it first).

## Phase 2: network and cluster (target 2026-11-12/13)

**Outcome:** an EKS 1.37 cluster with 2 Ready nodes, reachable only from the operator CIDR.

**Included:** `infra/` with S3 backend, VPC (3 AZ public subnets, no NAT, subnet tags for
LBC and Karpenter discovery), EKS module, managed node group 2 × m7i-flex.large, managed add-ons,
access entry for the operator, audit logs with 1-day retention, Pod Identity roles for EBS
CSI.

**Dependencies and risks:** FREE plan may block `CreateCluster` (unknown). Cost starts here.
The EKS module creates many IAM objects, so read the plan line by line.

**Exit criteria:**
- [ ] `kubectl get nodes` shows 2 Ready nodes on v1.37
- [ ] `infra` plan is empty after apply
- [ ] public access CIDRs equal `var.operator_cidrs`

**Validation:**
- Automated: local gate, CI plan on the PR
- Manual: `kubectl get nodes -o wide`, `aws eks list-access-entries`

**Rollback:** `terraform -chdir=infra destroy`.

## Phase 3: platform bootstrap (target 2026-11-13)

**Outcome:** Argo CD runs and owns everything under `gitops/`.

**Included:** Terraform `helm_release` for the AWS Load Balancer Controller (Pod Identity)
and Argo CD, Karpenter IAM, SQS interruption queue and Pod Identity, one root Application.
`gitops/platform/`: Karpenter chart, `EC2NodeClass`, `NodePool` (4 vCPU limit, spot and
on-demand), kube-prometheus-stack sized for 2 small nodes.

**Dependencies and risks:** Karpenter and LBC IAM policies are large; pin them to upstream
policy versions. kube-prometheus-stack needs limits sized for 2 × 8 GiB nodes.

**Exit criteria:**
- [ ] all Applications `Synced` and `Healthy`
- [ ] a test `Ingress` gets an ALB address, then is deleted and the ALB goes away

**Validation:**
- Automated: `kubeconform` and `helm template` in CI, local gate
- Manual: `kubectl -n argocd get applications`, Argo CD UI screenshot

**Rollback:** delete the root Application (cascades), then `terraform apply` with the
platform module removed.

## Phase 4: application and CI/CD (target 2026-11-14)

**Outcome:** a merged code change reaches the cluster through ECR and a tag-bump PR.

**Included:** `app/fe`, `app/app1`, `app/app2` with Dockerfiles and unit tests; ECR repos;
`gitops/apps/chain` Kustomize base with Deployments, Services, HPA, PDB, Ingress;
`app` workflow: test, build, trivy, push on `main`, open tag-bump PR.

**Dependencies and risks:** the push role trust. The tag-bump PR needs `pull-requests: write`
for `GITHUB_TOKEN`, and PRs opened by `GITHUB_TOKEN` do not trigger workflows, so the PR's
own checks need `workflow_dispatch` or a manual re-run.

**Exit criteria:**
- [ ] `curl http://<alb>/api/fullchain` returns the full chain
- [ ] a code change goes from PR to running pod with no human `kubectl`

**Validation:**
- Automated: pytest, trivy, kubeconform, CI on the PR
- Manual: curl output, `kubectl get deploy -o wide`

## Phase 5: operations drills (target 2026-11-15/16)

**Outcome:** evidence for scaling, self-healing and rollback.

**Included:** load test job, HPA scale-out, Karpenter scale-out and consolidation, drift
self-heal, `git revert` rollback, node termination with workloads rescheduling. Grafana
dashboard for the chain. Each drill writes `docs/evidence/<drill>.md`.

**Exit criteria:** each matching SPEC acceptance criterion has a linked evidence file.

## Phase 6: write-up (target 2026-11-17/18)

**Outcome:** a recruiter understands the project in two minutes.

**Included:** README with architecture diagram, cost actuals from Cost Explorer, decisions
(`docs/adr/`), screenshots, resume bullet proposal.

## Phase 7: teardown to $0 (by 2026-11-19)

**Outcome:** no billable resource left in the account.

**Included:** delete Ingresses first (so LBC removes the ALB), delete Karpenter NodePools
(so Karpenter terminates its nodes), `terraform destroy` on `infra/`, empty and destroy
`bootstrap/`, sweep for leftover ENIs, EBS volumes, ALBs, log groups and ECR repos.

**Exit criteria:**
- [ ] `aws resourcegroupstaggingapi get-resources --tag-filters Key=project,Values=eks-gitops-platform` is empty
- [ ] `aws eks list-clusters`, `aws elbv2 describe-load-balancers`, `aws ec2 describe-volumes` show nothing of ours
- [ ] Cost Explorer daily spend reaches $0 on 2026-11-20
