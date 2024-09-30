
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

variable "admin_role_arn" {
  description = "ARN of the admin role"
  type        = string
  default     = ""

  validation {
    condition     = var.admin_role_arn == "" || can(regex("^arn:aws:iam::[0-9]{12}:role/.+", var.admin_role_arn))
    error_message = "The admin_role_arn value must be a valid IAM role ARN or an empty string."
  }
}