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

variable "arm_based_instances" {
  type    = bool
  default = false
}