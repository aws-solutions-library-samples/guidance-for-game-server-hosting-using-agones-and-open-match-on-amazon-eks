## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
variable "cluster_name" {
  type = string
}

# Example: "us-east-1"
# No default is set because this one module is replicated across multiple regions in the Terraform template.
# If the default value is used then it might conflict with the default value of the other Kubernetes Cluster in the other region
variable "cluster_region" {
  type = string
}

# Example: 10.0.0.0/16
# No default is set because this one module is replicated across multiple regions in the Terraform template.
# If the default value is used then it might conflict with the default value of the other Kubernetes Cluster in the other region
variable "cluster_cidr" {
  type = string
}

variable "cluster_version" {
  type    = string
  default = "1.28"
}

# Variable for ensuring that all available Managed Node Groups (MNGs) use arm-based instances
# This value must be set to false if the deployer wishes to use a combination of x86 and arm-based MNGs in the EKS Cluster
variable "all_mngs_use_arm_based_instance_types" {
  type    = bool
  default = false
}

# Variable for ensuring that nodes in the gamerservers Managed Node Group (MNG) use arm-based instances
# See ./main.tf to see all of the available MNGs in the cluster
variable "gameservers_mng_uses_arm_based_instances" {
  type    = bool
  default = false
}

# Default is an m5.large instance type: 2 vCPU, 8 GB Memory, EBS-Only Instance Storage, 10 Gbps Network Bandwidth, 4750 Mbps EBS Bandwidth
# Ensure that all instance types have the same specifications (same cpu and memory amounts) for proper scheduling and scaling
variable "gameservers_x86_instance_types" {
  type    = list(any)
  default = ["m5.large"]
}

# Default is an m7g.large instance type: 2 vCPU, 8 GB Memory, EBS-Only Instance Storage, 12.5 Gbps Network Bandwidth, 10 Gbps EBS Bandwidth
# Ensure that all instance types have the same specifications (same cpu and memory amounts) for proper scheduling and scaling
variable "gameservers_arm_instance_types" {
  type    = list(any)
  default = ["m7g.large"]
}

variable "gameservers_x86_based_ami_type" {
  type    = string
  default = "AL2_x86_64"
}

variable "gameservers_arm_based_ami_type" {
  type    = string
  default = "AL2_ARM_64"
}

variable "gameservers_min_size" {
  type    = number
  default = 1
}

variable "gameservers_max_size" {
  type    = number
  default = 6
}

variable "gameservers_desired_size" {
  type    = number
  default = 3
}

# Variable for ensuring that nodes in the agones system Managed Node Group (MNG) use arm-based instances
# See ./main.tf to see all of the available MNGs in the cluster
variable "agones_system_mng_uses_arm_based_instances" {
  type    = bool
  default = false
}

# Default is an m5.large instance type: 2 vCPU, 8 GB Memory, EBS-Only Instance Storage, 10 Gbps Network Bandwidth, 4750 Mbps EBS Bandwidth
# Ensure that all instance types have the same specifications (same cpu and memory amounts) for proper scheduling and scaling
variable "agones_system_x86_instance_types" {
  type    = list(any)
  default = ["m5.large"]
}

# Default is an m7g.large instance type: 2 vCPU, 8 GB Memory, EBS-Only Instance Storage, 12.5 Gbps Network Bandwidth, 10 Gbps EBS Bandwidth
# Ensure that all instance types have the same specifications (same cpu and memory amounts) for proper scheduling and scaling
variable "agones_system_arm_instance_types" {
  type    = list(any)
  default = ["m7g.large"]
}

variable "agones_system_x86_based_ami_type" {
  type    = string
  default = "AL2_x86_64"
}

variable "agones_system_arm_based_ami_type" {
  type    = string
  default = "AL2_ARM_64"
}

# Minimum must be at least 3 for multiple agones system pods unless you increase the ebs volume size per node
variable "agones_system_min_size" {
  type    = number
  default = 3
}

variable "agones_system_max_size" {
  type    = number
  default = 6
}

variable "agones_system_desired_size" {
  type    = number
  default = 3
}

# This variable currently is not used during cluster creation
variable "agones_system_ebs_size" {
  type    = number
  default = 50
}

# Variable for ensuring that nodes in the agones metrics Managed Node Group (MNG) use arm-based instances
# See ./main.tf to see all of the available MNGs in the cluster
variable "agones_metrics_mng_uses_arm_based_instances" {
  type    = bool
  default = false
}

# Default is an m5.large instance type: 2 vCPU, 8 GB Memory, EBS-Only Instance Storage, 10 Gbps Network Bandwidth, 4750 Mbps EBS Bandwidth
# Ensure that all instance types have the same specifications (same cpu and memory amounts) for proper scheduling and scaling
variable "agones_metrics_x86_instance_types" {
  type    = list(any)
  default = ["m5.large"]
}

# Default is an m7g.large instance type: 2 vCPU, 8 GB Memory, EBS-Only Instance Storage, 12.5 Gbps Network Bandwidth, 10 Gbps EBS Bandwidth
# Ensure that all instance types have the same specifications (same cpu and memory amounts) for proper scheduling and scaling
variable "agones_metrics_arm_instance_types" {
  type    = list(any)
  default = ["m7g.large"]
}

variable "agones_metrics_x86_based_ami_type" {
  type    = string
  default = "AL2_x86_64"
}

variable "agones_metrics_arm_based_ami_type" {
  type    = string
  default = "AL2_ARM_64"
}

variable "agones_metrics_min_size" {
  type    = number
  default = 1
}

variable "agones_metrics_max_size" {
  type    = number
  default = 3
}

variable "agones_metrics_desired_size" {
  type    = number
  default = 1
}

# Variable for ensuring that nodes in the openmatch Managed Node Group (MNG) use arm-based instances
# See ./main.tf to see all of the available MNGs in the cluster
# AS OF 8-21-2024, OPENMATCH DOES NOT SUPPORT ARM-BASED ARCHITECTURES
# variable "open_match_mng_uses_arm_based_instances" {
#   type    = bool
#   default = false
# }

# Default is an m5.large instance type: 2 vCPU, 8 GB Memory, EBS-Only Instance Storage, 10 Gbps Network Bandwidth, 4750 Mbps EBS Bandwidth
# Ensure that all instance types have the same specifications (same cpu and memory amounts) for proper scheduling and scaling
variable "open_match_x86_instance_types" {
  type    = list(any)
  default = ["m5.large"]
}

# Default is an m7g.large instance type: 2 vCPU, 8 GB Memory, EBS-Only Instance Storage, 12.5 Gbps Network Bandwidth, 10 Gbps EBS Bandwidth
# Ensure that all instance types have the same specifications (same cpu and memory amounts) for proper scheduling and scaling
# AS OF 8-21-2024, OPENMATCH DOES NOT SUPPORT ARM-BASED ARCHITECTURES
# variable "open_match_arm_instance_types" {
#   type    = list(any)
#   default = ["m7g.large"]
# }

variable "open_match_x86_based_ami_type" {
  type    = string
  default = "AL2_x86_64"
}

# AS OF 8-21-2024, OPENMATCH DOES NOT SUPPORT ARM-BASED ARCHITECTURES
# variable "open_match_arm_based_ami_type" {
#   type    = string
#   default = "AL2_ARM_64"
# }

variable "open_match_min_size" {
  type    = number
  default = 1
}

variable "open_match_max_size" {
  type    = number
  default = 6
}

variable "open_match_desired_size" {
  type    = number
  default = 3
}

# Variable for ensuring that nodes in the agones-openmatch Managed Node Group (MNG) use arm-based instances
# See ./main.tf to see all of the available MNGs in the cluster
# AS OF 8-21-2024, OPENMATCH DOES NOT SUPPORT ARM-BASED ARCHITECTURES
# variable "agones_open_match_mng_uses_arm_based_instances" {
#   type    = bool
#   default = false
# }

# Default is an m5.large instance type: 2 vCPU, 8 GB Memory, EBS-Only Instance Storage, 10 Gbps Network Bandwidth, 4750 Mbps EBS Bandwidth
# Ensure that all instance types have the same specifications (same cpu and memory amounts) for proper scheduling and scaling
variable "agones_open_match_x86_instance_types" {
  type    = list(any)
  default = ["m5.large"]
}

# Default is an m7g.large instance type: 2 vCPU, 8 GB Memory, EBS-Only Instance Storage, 12.5 Gbps Network Bandwidth, 10 Gbps EBS Bandwidth
# Ensure that all instance types have the same specifications (same cpu and memory amounts) for proper scheduling and scaling
# AS OF 8-21-2024, OPENMATCH DOES NOT SUPPORT ARM-BASED ARCHITECTURES
# variable "agones_open_match_arm_instance_types" {
#   type    = list(any)
#   default = ["m7g.large"]
# }

variable "agones_open_match_x86_based_ami_type" {
  type    = string
  default = "AL2_x86_64"
}

# AS OF 8-21-2024, OPENMATCH DOES NOT SUPPORT ARM-BASED ARCHITECTURES
# variable "agones_open_match_arm_based_ami_type" {
#   type    = string
#   default = "AL2_ARM_64"
# }

variable "agones_openmatch_min_size" {
  type    = number
  default = 1
}

variable "agones_openmatch_max_size" {
  type    = number
  default = 3
}

variable "agones_openmatch_desired_size" {
  type    = number
  default = 1
}

variable "gameserver_minport" {
  type    = number
  default = 7000
}

variable "gameserver_maxport" {
  type    = number
  default = 7029
}

variable "open_match" {
  type = bool
}

variable "admin_role_arn" {
  type        = string
  default     = ""
  description = "ARN of the admin role passed into the module"
}