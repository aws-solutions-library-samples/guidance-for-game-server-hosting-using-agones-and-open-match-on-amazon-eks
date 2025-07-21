## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
module "cluster1" {
  source                                      = "./modules/cluster"
  cluster_name                                = var.cluster_1_name
  cluster_region                              = var.cluster_1_region
  cluster_cidr                                = var.cluster_1_cidr
  open_match                                  = true
  all_mngs_use_arm_based_instance_types       = var.all_arm_based_instances_cluster_1
  gameservers_mng_uses_arm_based_instances    = var.gameservers_arm_based_instances_cluster_1
  agones_system_mng_uses_arm_based_instances  = var.agones_system_arm_based_instances_cluster_1
  agones_metrics_mng_uses_arm_based_instances = var.agones_metrics_arm_based_instances_cluster_1
  admin_role_arn                              = var.admin_role_arn_from_cloudformation
  codebuild_role_arn                          = var.codebuild_role_arn_from_cloudformation
}
module "cluster2" {
  source                                      = "./modules/cluster"
  cluster_name                                = var.cluster_2_name
  cluster_region                              = var.cluster_2_region
  cluster_cidr                                = var.cluster_2_cidr
  open_match                                  = false
  all_mngs_use_arm_based_instance_types       = var.all_arm_based_instances_cluster_2
  gameservers_mng_uses_arm_based_instances    = var.gameservers_arm_based_instances_cluster_2
  agones_system_mng_uses_arm_based_instances  = var.agones_system_arm_based_instances_cluster_2
  agones_metrics_mng_uses_arm_based_instances = var.agones_metrics_arm_based_instances_cluster_2
  admin_role_arn                              = var.admin_role_arn_from_cloudformation
  codebuild_role_arn                          = var.codebuild_role_arn_from_cloudformation
}
#--------------------------------------------------------------
# Adding guidance solution ID via AWS CloudFormation resource
#--------------------------------------------------------------
resource "aws_cloudformation_stack" "guidance_deployment_metrics" {
    name = "tracking-stack"
    template_body = <<STACK
    {
        "AWSTemplateFormatVersion": "2010-09-09",
        "Description": "AWS Guidance ID (SO9387)",
        "Resources": {
            "EmptyResource": {
                "Type": "AWS::CloudFormation::WaitConditionHandle"
            }
        }
    }
    STACK
}