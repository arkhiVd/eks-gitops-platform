# AWS Load Balancer Controller. Turns Ingress objects into ALBs. Its AWS permissions come
# from Pod Identity; the policy is vendored from the controller's v3.6.2 release.
resource "aws_iam_policy" "lbc" {
  name        = "${var.cluster_name}-aws-load-balancer-controller"
  description = "AWS Load Balancer Controller v3.6.2 upstream policy"
  policy      = file("${path.module}/policies/aws-load-balancer-controller-v3.6.2.json")
}

resource "aws_iam_role" "lbc" {
  name               = "${var.cluster_name}-aws-load-balancer-controller"
  description        = "Pod Identity role for the AWS Load Balancer Controller"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc.arn
}

resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "3.6.2"

  # IMDS hop limit 1 blocks pods from instance metadata, so region and VPC are passed in.
  set = [
    { name = "clusterName", value = module.eks.cluster_name },
    { name = "region", value = var.region },
    { name = "vpcId", value = module.vpc.vpc_id },
    { name = "serviceAccount.name", value = "aws-load-balancer-controller" },
    { name = "replicaCount", value = "1" },
    { name = "resources.requests.cpu", value = "50m" },
    { name = "resources.requests.memory", value = "128Mi" },
    { name = "resources.limits.memory", value = "256Mi" },
  ]

  depends_on = [aws_eks_pod_identity_association.lbc]
}
