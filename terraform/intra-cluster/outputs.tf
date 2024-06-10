## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
output "frontend_lb" {
  value = try(data.aws_lb.frontend_lb[0].dns_name, null)
}
