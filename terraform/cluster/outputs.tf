## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
output "vpc_1_id" {
  value = module.cluster1.vpc_id
}

output "private_1_subnets" {
  value = module.cluster1.private_subnets
}

output "gameservers_1_subnets" {
  value = module.cluster1.gameservers_subnets
}

output "private_route_table_1_id" {
  value = module.cluster1.private_route_table_id
}

output "cluster_1_certificate_authority_data" {
  sensitive   = true
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.cluster1.cluster_certificate_authority_data
}

output "cluster_1_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.cluster1.cluster_endpoint
}

output "cluster_1_token" {
  sensitive   = true
  description = "Endpoint for your Kubernetes API server"
  value       = module.cluster1.cluster_token
}

output "cluster_1_name" {
  description = "The name of the EKS cluster"
  value       = module.cluster1.cluster_name
}

output "oidc_provider_1_arn" {
  description = "The ARN of the OIDC Provider if `enable_irsa = true`"
  value       = module.cluster1.oidc_provider_arn
}

output "vpc_2_id" {
  value = module.cluster2.vpc_id
}

output "private_2_subnets" {
  value = module.cluster2.private_subnets
}

output "gameservers_2_subnets" {
  value = module.cluster2.gameservers_subnets
}

output "private_route_table_2_id" {
  value = module.cluster2.private_route_table_id
}

output "cluster_2_certificate_authority_data" {
  sensitive   = true
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.cluster2.cluster_certificate_authority_data
}

output "cluster_2_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.cluster2.cluster_endpoint
}

output "cluster_2_token" {
  sensitive   = true
  description = "Endpoint for your Kubernetes API server"
  value       = module.cluster2.cluster_token
}

output "cluster_2_name" {
  description = "The name of the EKS cluster"
  value       = module.cluster2.cluster_name
}

output "oidc_provider_2_arn" {
  description = "The ARN of the OIDC Provider if `enable_irsa = true`"
  value       = module.cluster2.oidc_provider_arn
}

output "admin_role_arn_from_cloudformation" { 
  description = "The ARN of the admin role passed to the BuildSpec from the CloudFormation template"
  value       = module.cluster1.admin_role_arn
}