## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
variable "cluster_endpoint" {
  type = string
}

variable "cluster_certificate_authority_data" {
  type = string
}

variable "cluster_token" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_region" {
  type = string
}

variable "cluster_version" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "configure_agones" {
  type = bool
}

variable "configure_open_match" {
  type = bool
}

variable "namespaces" {
  type = list(any)
}

