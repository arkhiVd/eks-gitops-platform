# 0003. Public subnets with no NAT gateway

Status: accepted, 2026-11-11

## Context

A NAT gateway costs $0.045/h plus data processing, about $32 per month each, or three times
that for one per AZ. The whole build had $131.69 of credit. Private nodes would also need
VPC endpoints or NAT to reach ECR, EKS and STS.

## Decision

The VPC has three public /20 subnets, one per AZ, and no NAT. Nodes get public IPv4
addresses. The node security group allows no inbound traffic from `0.0.0.0/0`, nodes have no
SSH key, and shell access goes through SSM Session Manager. The EKS public endpoint accepts
only `var.operator_cidrs`, and the variable's validation rejects `0.0.0.0/0`.

## Consequences

- About $0.02/h for public IPv4 instead of $0.045/h or more for NAT.
- Nodes are reachable by IP from the internet. Security groups are the only barrier, which
  a production cluster would not accept. Private subnets with NAT or endpoints are listed as
  a non-goal in `SPEC.md`.
- The operator CIDR changes whenever the VPN exit changes. Updating it is a one-line,
  in-place `terraform apply` with no replacement.
