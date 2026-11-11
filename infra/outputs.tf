output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API endpoint."
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "VPC ID, needed by the AWS Load Balancer Controller."
  value       = module.vpc.vpc_id
}

output "node_security_group_id" {
  description = "Shared node security group."
  value       = module.eks.node_security_group_id
}

output "kubeconfig_command" {
  description = "Command that writes a kubeconfig context for this cluster."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region} --alias ${module.eks.cluster_name}"
}

output "karpenter_node_role_name" {
  description = "Node role for Karpenter-launched nodes, used by the EC2NodeClass."
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_queue_name" {
  description = "SQS interruption queue, used by the Karpenter Helm values."
  value       = module.karpenter.queue_name
}

output "grafana_admin_password_command" {
  description = "Reads the Grafana admin password from the cluster. Never printed by Terraform."
  value       = "kubectl --context ${var.cluster_name} -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d"
}
