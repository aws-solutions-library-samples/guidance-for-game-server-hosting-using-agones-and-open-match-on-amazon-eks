## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "gameservers_subnets" {
  value = local.gameservers_subnet_ids
}

output "private_route_table_id" {
  value = module.vpc.private_route_table_ids[0]
}

output "cluster_certificate_authority_data" {
  sensitive   = true
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = try(module.eks.cluster_certificate_authority_data)
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = try(module.eks.cluster_endpoint)
}

output "cluster_token" {
  sensitive   = true
  description = "Endpoint for your Kubernetes API server"
  value       = try(data.aws_eks_cluster_auth.this.token)
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = try(module.eks.cluster_name)
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if `enable_irsa = true`"
  value       = try(module.eks.oidc_provider_arn, null)
}

output "admin_role_arn" {  
  description = "The ARN of the admin role passed to the module"
  value       = try(var.admin_role_arn, null)
}

# Debug outputs - these are additional and don't replace existing outputs
output "admin_role_name_debug" {
  description = "The extracted name of the admin role (for debugging)"
  value       = try(local.admin_role_name, "")
}

output "aws_auth_configmap_role_debug" {
  description = "The aws-auth configmap role (for debugging)"
  value       = try(module.eks_blueprints_admin_team.aws_auth_configmap_role, [])
}
