data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

# Public subnets only, no NAT gateway (SPEC: $0.045/h each is not worth it here). Nodes get
# public IPs, but the node security group allows no inbound traffic from the internet.
module "vpc" {
  # checkov:skip=CKV_TF_1:Registry module pinned to an exact version; the lock file pins provider hashes
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  name = var.cluster_name
  cidr = var.vpc_cidr
  azs  = local.azs

  public_subnets          = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i)]
  map_public_ip_on_launch = true

  enable_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Locks down the default security group (no rules) so nothing can use it by accident.
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "karpenter.sh/discovery" = var.cluster_name
  }
}
