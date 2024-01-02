
## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
variable "ecr_region" {
  type    = string
  # default = "us-east-1"
}

# CIDR values must not overlap
variable "cluster_1_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "cluster_2_cidr" {
  type    = string
  default = "10.2.0.0/16"
}

variable "cluster_1_name" {
  type    = string
  default = "agones-gameservers-1"
}

variable "cluster_1_region" {
  type    = string
  # default = "us-east-1"
}
variable "cluster_1_endpoint" {
  type = string
}

variable "cluster_1_certificate_authority_data" {
  type = string
}

variable "cluster_1_token" {
  type = string
}
variable "cluster_2_endpoint" {
  type = string
}

variable "cluster_2_certificate_authority_data" {
  type = string
}

variable "cluster_2_token" {
  type = string
}
variable "cluster_2_name" {
  type    = string
  default = "agones-gameservers-2"
}

variable "cluster_2_region" {
  type    = string
  # default = "us-east-2"
}

variable "requester_cidr" {
  type = string
}
variable "requester_vpc_id" {
  type = string
}
variable "requester_route" {
  type = string
}
variable "accepter_cidr" {
  type = string
}
variable "accepter_vpc_id" {
  type = string
}
variable "accepter_route" {
  type = string
}
variable "cluster_1_gameservers_subnets" {
  type = list(any)
}
variable "cluster_2_gameservers_subnets" {
  type = list(any)
}