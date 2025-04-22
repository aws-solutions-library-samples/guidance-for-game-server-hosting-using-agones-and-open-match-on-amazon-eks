## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = try(module.eks.cluster_name, "")
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = try(module.eks.cluster_endpoint, "")
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = try(module.eks.cluster_certificate_authority_data, "")
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = try(module.vpc.vpc_id, "")
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = try(module.vpc.private_subnets, [])
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = try(module.vpc.public_subnets, [])
}

output "gameservers_subnet_ids" {
  description = "List of IDs of gameservers subnets"
  value       = try(local.gameservers_subnet_ids, [])
}

output "private_route_table_ids" {
  description = "List of IDs of private route tables"
  value       = try(module.vpc.private_route_table_ids, [])
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = try(module.eks.oidc_provider_arn, "")
}

output "cluster_token" {
  description = "The token to use to authenticate with the cluster"
  value       = try(data.aws_eks_cluster_auth.this.token, "")
  sensitive   = true
}

# Debug outputs
output "admin_role_arn_debug" {
  description = "The ARN of the admin role (for debugging)"
  value       = try(var.admin_role_arn, "")
}

output "admin_role_name_debug" {
  description = "The extracted name of the admin role (for debugging)"
  value       = try(local.admin_role_name, "")
}

output "aws_auth_configmap_role_debug" {
  description = "The aws-auth configmap role (for debugging)"
  value       = try(module.eks_blueprints_admin_team.aws_auth_configmap_role, [])
}
