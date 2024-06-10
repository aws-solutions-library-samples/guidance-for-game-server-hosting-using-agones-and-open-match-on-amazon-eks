## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
provider "aws" {
  region = var.cluster_1_region
}

provider "aws" {
  alias  = "ecr"
  region = var.cluster_1_region
}
provider "aws" {
  alias  = "peer"
  region = var.cluster_2_region
}

data "aws_caller_identity" "current" {}


## ECR
resource "aws_ecr_replication_configuration" "cross_ecr_replication" {
  replication_configuration {
    rule {
      destination {
        region      = var.cluster_2_region
        registry_id = data.aws_caller_identity.current.account_id
      }
    }
  }
}
resource "aws_ecr_repository" "agones-openmatch-director" {
  #checkov:skip=CKV_AWS_136:Encryption disabled for tests
  name                 = "agones-openmatch-director"
  image_tag_mutability = "IMMUTABLE" # Remove if you need to push the container with the same tag to the ECR (not recommended)
  force_delete         = true # Remove to avoid destroying when not empty
  image_scanning_configuration {
    scan_on_push = true
  }
}
resource "aws_ecr_repository" "agones-openmatch-mmf" {
  #checkov:skip=CKV_AWS_136:Encryption disabled for tests
  name                 = "agones-openmatch-mmf"
  image_tag_mutability = "IMMUTABLE" # Remove if you need to push the container with the same tag to the ECR (not recommended)
  force_delete         = true # Remove to avoid destroying when not empty
  image_scanning_configuration {
    scan_on_push = true
  }
}
resource "aws_ecr_repository" "agones-openmatch-ncat-server" {
  #checkov:skip=CKV_AWS_136:Encryption disabled for tests
  name                 = "agones-openmatch-ncat-server"
  image_tag_mutability = "IMMUTABLE" # Remove if you need to push the container with the same tag to the ECR (not recommended)
  force_delete         = true # Remove to avoid destroying when not empty
  image_scanning_configuration {
    scan_on_push = true
  }
}

## Peering
# Requester's side of the connection.
resource "aws_vpc_peering_connection" "peer" {
  vpc_id      = var.requester_vpc_id
  peer_vpc_id = var.accepter_vpc_id
  peer_region = var.cluster_2_region
  auto_accept = false

  tags = {
    Side = "Requester"
  }
}

# Accepter's side of the connection.
resource "aws_vpc_peering_connection_accepter" "peer" {
  provider                  = aws.peer
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true

  tags = {
    Side = "Accepter"
  }
}

resource "aws_route" "requester" {
  route_table_id            = var.requester_route
  destination_cidr_block    = var.accepter_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

resource "aws_route" "accepter" {
  provider                  = aws.peer
  route_table_id            = var.accepter_route
  destination_cidr_block    = var.requester_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}


## AWS Global Accelerators

resource "aws_globalaccelerator_accelerator" "aga_frontend" {
  #checkov:skip=CKV_AWS_75:Flow logs not needed
  name            = "${var.cluster_1_name}-om-fe"
  ip_address_type = "IPV4"
  enabled         = true

}

resource "aws_globalaccelerator_listener" "aga_frontend" {
  accelerator_arn = aws_globalaccelerator_accelerator.aga_frontend.id
  protocol        = "TCP"

  port_range {
    from_port = 50504
    to_port   = 50504
  }
}

resource "aws_globalaccelerator_endpoint_group" "aga_frontend" {
  listener_arn = aws_globalaccelerator_listener.aga_frontend.id

  endpoint_configuration {
    endpoint_id                    = var.aws_lb_arn
    client_ip_preservation_enabled = false
    weight                         = 100
  }
}

## Game servers Accelerators
resource "aws_globalaccelerator_custom_routing_accelerator" "aga_gs_cluster_1" {
  name            = "agones-openmatch-gameservers-cluster-1"
  ip_address_type = "IPV4"
  enabled         = true

}

resource "aws_globalaccelerator_custom_routing_listener" "aga_gs_cluster_1" {
  accelerator_arn = aws_globalaccelerator_custom_routing_accelerator.aga_gs_cluster_1.id
  port_range {
    from_port = 1
    to_port   = 65535
  }
}

resource "aws_globalaccelerator_custom_routing_endpoint_group" "aga_gs_cluster_1" {
  listener_arn          = aws_globalaccelerator_custom_routing_listener.aga_gs_cluster_1.id
  endpoint_group_region = var.cluster_1_region
  destination_configuration {
    from_port = 7000
    to_port   = 7029
    protocols = ["TCP","UDP"]
  }

  endpoint_configuration {
    endpoint_id = var.cluster_1_gameservers_subnets[0]
  }
  endpoint_configuration {
    endpoint_id = var.cluster_1_gameservers_subnets[1]
  }
  # endpoint_configuration {
  #   endpoint_id = var.cluster_1_gameservers_subnets[2]
  # }
}
resource "null_resource" "allow_custom_routing_traffic_cluster_1" {

  triggers = {
    always_run         = "${timestamp()}"
    endpoint_group_arn = aws_globalaccelerator_custom_routing_endpoint_group.aga_gs_cluster_1.id
    endpoint_id_1      = var.cluster_1_gameservers_subnets[0]
    endpoint_id_2      = var.cluster_1_gameservers_subnets[1]
    # endpoint_id_3      = var.cluster_1_gameservers_subnets[2]
  }

  provisioner "local-exec" {
    command = "aws globalaccelerator allow-custom-routing-traffic --endpoint-group-arn ${self.triggers.endpoint_group_arn} --endpoint-id ${self.triggers.endpoint_id_1} --allow-all-traffic-to-endpoint --region us-west-2;aws globalaccelerator allow-custom-routing-traffic --endpoint-group-arn ${self.triggers.endpoint_group_arn} --endpoint-id ${self.triggers.endpoint_id_2} --allow-all-traffic-to-endpoint --region us-west-2"
  }
  depends_on = [
    aws_globalaccelerator_custom_routing_endpoint_group.aga_gs_cluster_1
  ]
}

resource "aws_globalaccelerator_custom_routing_accelerator" "aga_gs_cluster_2" {
  name            = "agones-openmatch-gameservers-cluster-2"
  ip_address_type = "IPV4"
  enabled         = true

}

resource "aws_globalaccelerator_custom_routing_listener" "aga_gs_cluster_2" {
  accelerator_arn = aws_globalaccelerator_custom_routing_accelerator.aga_gs_cluster_2.id
  port_range {
    from_port = 1
    to_port   = 65535
  }
}

resource "aws_globalaccelerator_custom_routing_endpoint_group" "aga_gs_cluster_2" {
  listener_arn          = aws_globalaccelerator_custom_routing_listener.aga_gs_cluster_2.id
  endpoint_group_region = var.cluster_2_region
  destination_configuration {
    from_port = 7000
    to_port   = 7029
    protocols = ["TCP","UDP"]
  }

  endpoint_configuration {
    endpoint_id = var.cluster_2_gameservers_subnets[0]
  }
  endpoint_configuration {
    endpoint_id = var.cluster_2_gameservers_subnets[1]
  }
  # endpoint_configuration {
  #   endpoint_id = var.cluster_2_gameservers_subnets[2]
  # }
}

resource "null_resource" "allow_custom_routing_traffic_cluster_2" {

  triggers = {
    always_run         = "${timestamp()}"
    endpoint_group_arn = aws_globalaccelerator_custom_routing_endpoint_group.aga_gs_cluster_2.id
    endpoint_id_1      = var.cluster_2_gameservers_subnets[0]
    endpoint_id_2      = var.cluster_2_gameservers_subnets[1]
    # endpoint_id_3      = var.cluster_2_gameservers_subnets[2]
  }

  provisioner "local-exec" {
    command = "aws globalaccelerator allow-custom-routing-traffic --endpoint-group-arn ${self.triggers.endpoint_group_arn} --endpoint-id ${self.triggers.endpoint_id_1} --allow-all-traffic-to-endpoint --region us-west-2;aws globalaccelerator allow-custom-routing-traffic --endpoint-group-arn ${self.triggers.endpoint_group_arn} --endpoint-id ${self.triggers.endpoint_id_2} --allow-all-traffic-to-endpoint --region us-west-2"
  }

  depends_on = [
    aws_globalaccelerator_custom_routing_endpoint_group.aga_gs_cluster_2
  ]
}

resource "null_resource" "aga_mapping_cluster_1" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    when    = create
    command = "nohup ${path.cwd}/scripts/deploy-mapping-configmap.sh ${var.cluster_1_name} ${aws_globalaccelerator_custom_routing_accelerator.aga_gs_cluster_1.id} ${var.cluster_2_name} ${aws_globalaccelerator_custom_routing_accelerator.aga_gs_cluster_2.id}&"
  }

  depends_on = [
    aws_globalaccelerator_custom_routing_endpoint_group.aga_gs_cluster_1,
    aws_globalaccelerator_custom_routing_endpoint_group.aga_gs_cluster_2
  ]
}


## Agones multi-cluster allocation
resource "null_resource" "multicluster_allocation" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    when    = create
    command = "nohup ${path.cwd}/scripts/configure-multicluster-allocation.sh ${var.cluster_1_name} ${var.cluster_2_name} ${path.cwd}&"
  }

}
