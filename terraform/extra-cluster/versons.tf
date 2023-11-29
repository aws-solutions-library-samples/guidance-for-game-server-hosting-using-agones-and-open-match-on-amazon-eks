## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.8.0"
    }
    # kubernetes = {
    #   source  = "hashicorp/kubernetes"
    #   version = ">= 2.22.0"
    # }
    # helm = {
    #   source  = "hashicorp/helm"
    #   version = ">= 2.10.1"
    # }
  }
  backend "s3" {
    key = "extra-cluster/terraform.tfstate"
  }
}
