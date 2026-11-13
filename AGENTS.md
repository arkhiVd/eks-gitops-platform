# eks-gitops-platform: agent instructions

## Purpose

An EKS 1.37 platform with pull-based GitOps on the AWS free-plan account `348032171026`,
built and torn down between 2026-11-11 and 2026-11-19. Terraform builds the cluster, Argo CD
deploys everything else from `gitops/`, GitHub Actions builds images and opens tag-bump PRs.
`SPEC.md` is the contract and `ROADMAP.md` holds the phases.

## Architecture

- `bootstrap/` holds local state, never committed: state bucket, GitHub OIDC provider, CI roles, budget
- `infra/` uses the S3 backend: VPC, EKS, node group, add-ons, IAM for in-cluster controllers, LBC and Argo CD Helm releases
- `gitops/` is everything Argo CD syncs. `gitops/root.yaml` is the app-of-apps entry
- `app/` holds the three service sources (`fe`, `app1`, `app2`) with Dockerfiles and tests
- `docs/evidence/` holds proof for each SPEC acceptance criterion; `docs/adr/` holds decisions
- Generated, never hand-edited: `*.tfstate*`, `.terraform/`, `.terraform.lock.hcl` (only `terraform init` updates it)
- External: AWS `348032171026` in `us-east-1`, ECR, GitHub `arkhiVd/eks-gitops-platform` (public)
- Toolchain pins live in `SPEC.md` § Pinned versions. Update SPEC first, then code.

## Commands

```bash
# format
terraform fmt -recursive

# local gate, all of it, before reporting done
terraform fmt -recursive -check
terraform -chdir=bootstrap init -backend=false && terraform -chdir=bootstrap validate
terraform -chdir=infra init -backend=false && terraform -chdir=infra validate
tflint --recursive
checkov -d . --framework terraform kubernetes github_actions --skip-path .terraform --quiet --compact
trivy config --severity HIGH,CRITICAL --skip-dirs '**/.terraform' --ignorefile .trivyignore.yaml .
actionlint
kubeconform -strict -summary -ignore-filename-pattern values.yaml -ignore-filename-pattern README -ignore-filename-pattern kustomization.yaml -schema-location default -schema-location https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json gitops/
gitleaks git --staged --redact .   # before commit; .terraform/ module examples trip --no-git
gitleaks git --redact .            # history
git diff --check

# plan (operator credentials, default AWS profile)
terraform -chdir=bootstrap plan -out=tfplan
terraform -chdir=infra plan -out=tfplan

# daily spend check, credits excluded (run every session; no AWS Budget exists)
aws ce get-cost-and-usage --time-period Start=2026-11-01,End=$(date -u -d tomorrow +%F) \
  --granularity DAILY --metrics UnblendedCost \
  --filter '{"Not":{"Dimensions":{"Key":"RECORD_TYPE","Values":["Credit"]}}}' \
  --query 'ResultsByTime[].[TimePeriod.Start,Total.UnblendedCost.Amount]' --output text
aws freetier get-account-plan-state --region us-east-1 --query accountPlanRemainingCredits.amount

# cluster access, after Phase 2
aws eks update-kubeconfig --name eks-gitops --region us-east-1 --alias eks-gitops
kubectl --context eks-gitops get nodes
kubectl --context eks-gitops -n argocd get applications
```

# app (Phase 4)
uv venv -q app/.venv && uv pip install -q -p app/.venv -r app/requirements-dev.txt
app/.venv/bin/ruff check . && app/.venv/bin/ruff format --check .
app/.venv/bin/pytest -q app
for s in fe app1 app2; do docker build -q -t eks-gitops/$s:local app/$s; done
for s in fe app1 app2; do trivy image --severity HIGH,CRITICAL --ignore-unfixed eks-gitops/$s:local; done
kubectl kustomize gitops/workloads/chain | kubeconform -strict -summary -

## Working boundaries

- Branch first; never commit or push to `main`.
- The agent runs `terraform apply` and `terraform destroy` (Aravind's instruction,
  2026-11-11). Only from a saved plan file (`apply tfplan`), only after reading that plan line
  by line and posting creates / changes / destroys / replaces and the hourly cost delta.
  An unexpected destroy or replace stops the apply until Aravind confirms.
- No `helm install/upgrade` or mutating `kubectl` outside Terraform and Argo CD, except the
  drills in Phase 5 that the ROADMAP names, and short-lived smoke objects in namespace
  `smoke` that are deleted in the same session.
- Testing a gitops change before merge: apply with `-var gitops_revision=<branch>` and point
  `gitops/apps/*` at the branch. The PR's last commit points them back at `main` (CI checks),
  and the first apply after merge uses `main` again.
- Read-only AWS and `kubectl get/describe/logs` calls are fine.
- Never touch the bucket `test-debzm` or anything without the `project=eks-gitops-platform` tag.
- Never commit `*.tfvars`, `.env`, kubeconfigs, plan files, or state.
- Blast radius: EKS control plane, EC2 nodes, ALB, public IPv4 and EBS all bill hourly. The
  account closes 2026-11-20 16:23 UTC. Teardown is due by 2026-11-19.
- Every resource carries default tags `project=eks-gitops-platform` and `owner=arkhiVd`.
- Commits: conventional with scope (`feat(infra):`), author `arkhiVd`. No AI attribution of
  any kind, no `Co-Authored-By` trailer. This repo is hiring evidence.

## Validation

- Paste real command output. A report is not evidence. Name every skipped check and its risk.
- Terraform: read the plan line by line and state creates / changes / destroys / replaces
  in the PR. Any destroy or replace you did not expect stops the phase.
- State the cost delta per hour for any plan that adds billable resources.
- Kubernetes: `kubeconform` locally, then Argo CD sync status on the real cluster.

## Documentation routing

- `SPEC.md`: requirements, pinned versions, cost, acceptance criteria
- `ROADMAP.md`: phases, gates, deadline
- `TASKS.md`: current phase and validation status
- Vault knowledge layer: `~/Documents/myvault/Projects/eks-gitops-platform.md`
- Workflow contract: `~/Documents/myvault/Systems/workflows/project-dev.md`
- Account limits: vault memory `aws-free-plan-account-gotchas`

## Maintenance

Keep this file short enough to follow. Add a rule only when it prevents a real repeat
mistake. When corrected, tighten the existing rule instead of adding a warning.
