## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
module "cluster1" {
  source         = "./modules/cluster"
  cluster_name   = var.cluster_1_name
  cluster_region = var.cluster_1_region
  cluster_cidr   = var.cluster_1_cidr
  open_match     = true
}
module "cluster2" {
  source         = "./modules/cluster"
  cluster_name   = var.cluster_2_name
  cluster_region = var.cluster_2_region
  cluster_cidr   = var.cluster_2_cidr
  open_match     = false
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