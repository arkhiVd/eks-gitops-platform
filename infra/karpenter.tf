# Karpenter AWS side: controller role (Pod Identity), node role with access entry, SQS
# interruption queue and EventBridge rules. The chart and NodePools live in gitops/.
module "karpenter" {
  # checkov:skip=CKV_TF_1:Registry module pinned to an exact version; the lock file pins provider hashes
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.29.0"

  cluster_name = module.eks.cluster_name

  namespace       = "kube-system"
  service_account = "karpenter"

  iam_role_name            = "${var.cluster_name}-karpenter-controller"
  iam_role_use_name_prefix = false

  # Fixed name: gitops/platform/karpenter-nodes/ec2nodeclass.yaml refers to it.
  node_iam_role_name            = "${var.cluster_name}-karpenter-node"
  node_iam_role_use_name_prefix = false
  node_iam_role_additional_policies = {
    ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # Fixed name: the Karpenter Application passes it as settings.interruptionQueue.
  queue_name = "${var.cluster_name}-karpenter"
}
