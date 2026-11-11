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
