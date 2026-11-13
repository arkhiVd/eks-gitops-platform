module "eks" {
  # checkov:skip=CKV_TF_1:Registry module pinned to an exact version; the lock file pins provider hashes
  source  = "terraform-aws-modules/eks/aws"
  version = "21.29.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # API endpoint: public, but only from the operator's CIDRs. Nodes use the private endpoint.
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.operator_cidrs
  endpoint_private_access      = true

  # Access entries only, no aws-auth ConfigMap. The caller that creates the cluster
  # (the operator's IAM user) becomes cluster admin through an access entry.
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  # Pod Identity for every AWS permission in the cluster, so no IRSA OIDC provider.
  enable_irsa = false

  enabled_log_types                      = ["audit"]
  cloudwatch_log_group_retention_in_days = 1

  # Versions resolved 2026-11-11 with `aws eks describe-addon-versions` (default for 1.37).
  addons = {
    vpc-cni = {
      addon_version  = "v1.22.4-eksbuild.14"
      before_compute = true
      # Runs the network policy agent so NetworkPolicy objects are enforced (eBPF).
      configuration_values = jsonencode({ enableNetworkPolicy = "true" })
    }
    eks-pod-identity-agent = {
      addon_version  = "v1.4.1-eksbuild.3"
      before_compute = true
    }
    kube-proxy = {
      addon_version = "v1.37.0-eksbuild.39"
    }
    coredns = {
      addon_version = "v1.14.7-eksbuild.35"
    }
    metrics-server = {
      addon_version = "v0.9.0-eksbuild.14"
    }
    aws-ebs-csi-driver = {
      addon_version = "v1.67.2-eksbuild.1"
      pod_identity_association = [{
        role_arn        = aws_iam_role.ebs_csi.arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
  }

  eks_managed_node_groups = {
    system = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND"

      # Fixed at 2. Karpenter (Phase 3) adds burst capacity, capped at 4 vCPU.
      # m7i-flex.large: 2 vCPU, 8 GiB, 29 pods per node, free-plan eligible.
      min_size     = 2
      max_size     = 2
      desired_size = 2

      block_device_mappings = {
        root = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      # IMDSv2 only, hop limit 1: pods cannot reach node credentials through IMDS.
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }

      # SSM Session Manager instead of SSH. No key pair is set.
      iam_role_additional_policies = {
        ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      labels = {
        "node-role" = "system"
      }
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}
