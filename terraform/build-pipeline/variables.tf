variable "s3_bucket" {
  type        = string
  description = "Name of the S3 bucket for storing Terraform state"
}

variable "dynamodb_table" {
  type        = string
  description = "Name of the DynamoDB table for locking Terraform state"
}

variable "dynamodb_table_deletion_protection" {
  type        = bool
  description = "Enable DynamoDB table deletion protection"
  default     = true
}
