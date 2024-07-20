terraform {
  backend "s3" {
    bucket              = var.s3_bucket
    force_destroy       = false 
    key                 = "agoe/terraform.tfstate"
    region              = "us-east-1"
    dynamodb_table      = var.dynamodb_table
    deletion_protection = var.dynamodb_table_deletion_protection
    encrypt             = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.75"
    }
  }
}
