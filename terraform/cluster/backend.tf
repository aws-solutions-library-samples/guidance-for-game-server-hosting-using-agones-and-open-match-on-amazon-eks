terraform {
  backend "s3" {
    # This block is intentionally empty.
    # Backend configuration will be provided via -backend-config parameters
    # when initializing Terraform in the automated pipeline.
  }
}