## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0

# CIDR values must not overlap
variable "cluster_1_cidr" {
  type    = string
  default = "10.1.0.0/16"
}
variable "cluster_1_name" {
  type    = string
}
variable "cluster_1_region" {
  type    = string
  default = "us-east-1"
}
variable "cluster_2_cidr" {
  type    = string
  default = "10.2.0.0/16"
}
variable "cluster_2_name" {
  type    = string
}
variable "cluster_2_region" {
  type    = string
  default = "us-east-2"
}

variable "open_match" {
  type    = bool
  default = false
}

variable "cluster_version" {
  type    = string
  default = "1.28"
}

# Variable for ensuring that all available Managed Node Groups (MNGs) use arm-based instances
# This value must be set to false if the deployer wishes to use a combination of x86 and arm-based MNGs in the EKS Cluster
variable "all_arm_based_instances_cluster_1" {
  type    = bool
  default = false
}

# Variable for ensuring that all available Managed Node Groups (MNGs) use arm-based instances
# This value must be set to false if the deployer wishes to use a combination of x86 and arm-based MNGs in the EKS Cluster
variable "all_arm_based_instances_cluster_2" {
  type    = bool
  default = false
}

# Variable for ensuring that nodes in the gamerservers Managed Node Group (MNG) use arm-based instances
# See ./modules/cluster/main.tf to see all of the available MNGs in the cluster
variable "gameservers_arm_based_instances_cluster_1" {
  type    = bool
  default = false
}

# Variable for ensuring that nodes in the gamerservers Managed Node Group (MNG) use arm-based instances
# See ./modules/cluster/main.tf to see all of the available MNGs in the cluster
variable "gameservers_arm_based_instances_cluster_2" {
  type    = bool
  default = false
}

# Variable for ensuring that nodes in the agones Managed Node Group (MNG) use arm-based instances
# See ./modules/cluster/main.tf to see all of the available MNGs in the cluster
variable "agones_system_arm_based_instances_cluster_1" {
  type    = bool
  default = false
}

# Variable for ensuring that nodes in the agones Managed Node Group (MNG) use arm-based instances
# See ./modules/cluster/main.tf to see all of the available MNGs in the cluster
variable "agones_system_arm_based_instances_cluster_2" {
  type    = bool
  default = false
}

# Variable for ensuring that nodes in the agones Managed Node Group (MNG) use arm-based instances
# See ./modules/cluster/main.tf to see all of the available MNGs in the cluster
variable "agones_metrics_arm_based_instances_cluster_1" {
  type    = bool
  default = false
}

# Variable for ensuring that nodes in the agones Managed Node Group (MNG) use arm-based instances
# See ./modules/cluster/main.tf to see all of the available MNGs in the cluster
variable "agones_metrics_arm_based_instances_cluster_2" {
  type    = bool
  default = false
}

# Variable for ensuring that nodes in the openmatch Managed Node Group (MNG) use arm-based instances
# See ./modules/cluster/main.tf to see all of the available MNGs in the cluster
# AS OF 8-21-2024, OPENMATCH DOES NOT SUPPORT ARM-BASED ARCHITECTURES
# variable "open_match_arm_based_instances_cluster_1" {
#   type    = bool
#   default = false
# }

# Variable for ensuring that nodes in the openmatch Managed Node Group (MNG) use arm-based instances
# See ./modules/cluster/main.tf to see all of the available MNGs in the cluster
# AS OF 8-21-2024, OPENMATCH DOES NOT SUPPORT ARM-BASED ARCHITECTURES
# variable "open_match_arm_based_instances_cluster_2" {
#   type    = bool
#   default = false
# }

# Variable for ensuring that nodes in the agones-openmatch Managed Node Group (MNG) use arm-based instances
# See ./modules/cluster/main.tf to see all of the available MNGs in the cluster
# AS OF 8-21-2024, OPENMATCH DOES NOT SUPPORT ARM-BASED ARCHITECTURES
# variable "agones_open_match_arm_based_instances_cluster_1" {
#   type    = bool
#   default = false
# }

# Variable for ensuring that nodes in the agones-openmatch Managed Node Group (MNG) use arm-based instances
# See ./modules/cluster/main.tf to see all of the available MNGs in the cluster
# AS OF 8-21-2024, OPENMATCH DOES NOT SUPPORT ARM-BASED ARCHITECTURES
# variable "agones_open_match_arm_based_instances_cluster_2" {
#   type    = bool
#   default = false
# }

variable "admin_role_arn_from_cloudformation" {
  type        = string
  default     = ""
  description = "ARN of the admin role"

}