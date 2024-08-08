## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0

# Description
Running log of recent changes, on a git commit level. The purpose of this document is to provide more details about changes to the project without having overly verbose commit messages.

# Change Log
## 8-8-2024
TLDR; Pass in a boolean option when creating the core cluster in the CLI to switch between x86-based and arm-based instances in the cluster's Managed Node Group. The deployer is responsible for ensuring that the non-default instance types in the terraform variables files have the architecture that matches the expectation of the array they are in.

- Added new variables to both of the terraform variables files in the core EKS Cluster (/terraform/cluster/variables.tf & /terraform/cluster/modules/cluster/variables.tf). These new variables enable people to switch between using an array of x86-based instances and an array of arm-based instances for the nodes in the core EKS cluster. A boolean variable was added to the /terraform/cluster/variables.tf file to enable dynamic switching between x86-based instances and arm-based instances in the EKS Module terraform file (/terraform/cluster/modules/cluster/main.tf).
- Modified the EKS Module terraform file (/terraform/cluster/modules/cluster/main.tf) so that based on the boolean option passed into the terraform cluster creation command, either an array of x86-based instance types or an array of arm-based instance types will be used for provisioning nodes in the main Managed Node Group of the core cluster.
- @sdpoueme and I had a discussion about enforcing arm-based and x86-based instance types in the two arrays, but in the end it was decided that it is up to the deployer to ensure that the correct instance types are in their appropriate array. We will ensure that the defaults are always correct.
- The new command for launching the core EKS Cluster through terraform with arm-based instances will be like so:
\# Initialize Terraform
terraform -chdir=terraform/cluster init &&
\# Create both clusters
terraform -chdir=terraform/cluster apply -auto-approve \
 -var="cluster_1_name=${CLUSTER1}" \
 -var="cluster_1_region=${REGION1}" \
 -var="cluster_1_cidr=${CIDR1}" \
 -var="cluster_2_name=${CLUSTER2}" \
 -var="cluster_2_region=${REGION2}" \
 -var="cluster_2_cidr=${CIDR2}" \
 -var="cluster_version=${VERSION}" \
 -var="arm_based_instances"=true
- Minor updates to the main README.md file to clarify installation and deployment instructions
- In this commit, all instance and ami types in the core cluster (gameservers, agones, openmatch, etc.) are toggled between x86 and arm architectures through the one option in the cli command (arm_based_instances=true). So all instances and ami's are either arm-based or x86-based.