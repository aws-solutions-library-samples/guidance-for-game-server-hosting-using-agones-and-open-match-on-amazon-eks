## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
output "global_accelerator_address" {
  value = aws_globalaccelerator_accelerator.aga_frontend.dns_name
}