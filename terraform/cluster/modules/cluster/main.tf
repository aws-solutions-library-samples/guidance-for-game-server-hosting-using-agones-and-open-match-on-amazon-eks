## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
locals {
  gameservers_subnet_ids      = slice(module.vpc.private_subnets, 0, 2)
  agones_system_subnet_ids    = slice(module.vpc.private_subnets, 2, 4)
  agones_metrics_subnet_ids   = slice(module.vpc.private_subnets, 4, 6)
  open_match_subnet_ids       = slice(module.vpc.private_subnets, 6, 8)
  agones_openmatch_subnet_ids = slice(module.vpc.private_subnets, 8, 10)
  azs                         = slice(data.aws_availability_zones.available.names, 0, 2)
  # Extract role name from the ARN only if admin_role_arn is provided
  admin_role_name = var.admin_role_arn != "" ? split("/", var.admin_role_arn)[length(split("/", var.admin_role_arn)) - 1] : ""
  tags = {
    Blueprint  = var.cluster_name
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }

  # gameservers instance and ami types
  gameservers_instance_types  = ((var.all_mngs_use_arm_based_instance_types == true) || (var.gameservers_mng_uses_arm_based_instances == true) ? var.gameservers_arm_instance_types : var.gameservers_x86_instance_types)
  gameservers_ami_type        = ((var.all_mngs_use_arm_based_instance_types == true) || (var.gameservers_mng_uses_arm_based_instances == true) ? var.gameservers_arm_based_ami_type : var.gameservers_x86_based_ami_type)

  # agones_system instance and ami types
  agones_system_instance_types = ((var.all_mngs_use_arm_based_instance_types == true) || (var.agones_system_mng_uses_arm_based_instances == true) ? var.agones_system_arm_instance_types : var.agones_system_x86_instance_types)
  agones_system_ami_type       = ((var.all_mngs_use_arm_based_instance_types == true) || (var.agones_system_mng_uses_arm_based_instances == true) ? var.agones_system_arm_based_ami_type : var.agones_system_x86_based_ami_type)

  # agones_metrics instance and ami types
  agones_metrics_instance_types = ((var.all_mngs_use_arm_based_instance_types == true) || (var.agones_metrics_mng_uses_arm_based_instances == true) ? var.agones_metrics_arm_instance_types : var.agones_metrics_x86_instance_types)
  agones_metrics_ami_type = ((var.all_mngs_use_arm_based_instance_types == true) || (var.agones_metrics_mng_uses_arm_based_instances == true) ? var.agones_metrics_arm_based_ami_type : var.agones_metrics_x86_based_ami_type)

  # open_match instance and ami types
  # open_match_instance_types = ((var.all_mngs_use_arm_based_instance_types == true) || (var.open_match_mng_uses_arm_based_instances == true) ? var.open_match_arm_instance_types : var.open_match_x86_instance_types)
  open_match_instance_types = var.open_match_x86_instance_types
  # open_match_ami_type = ((var.all_mngs_use_arm_based_instance_types == true) || (var.open_match_mng_uses_arm_based_instances == true) ? var.open_match_arm_based_ami_type : var.open_match_x86_based_ami_type)
  open_match_ami_type = var.open_match_x86_based_ami_type

  # agones_openmatch instance and ami types
  # agones_open_match_instance_types = ((var.all_mngs_use_arm_based_instance_types == true) || (var.agones_open_match_mng_uses_arm_based_instances == true) ? var.agones_open_match_arm_instance_types : var.agones_open_match_x86_instance_types)
  agones_open_match_instance_types = var.agones_open_match_x86_instance_types
  # agones_open_match_ami_type = ((var.all_mngs_use_arm_based_instance_types == true) || (var.agones_open_match_mng_uses_arm_based_instances == true) ? var.agones_open_match_arm_based_ami_type : var.agones_open_match_x86_based_ami_type)
  agones_open_match_ami_type = var.agones_open_match_x86_based_ami_type
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}


provider "aws" {
  region = var.cluster_region
}

################################################################################
# Agones Cluster
################################################################################

#tfsec:ignore:aws-eks-enable-control-plane-logging
module "eks" {
  #checkov:skip=CKV_TF_1:Module registry does not support commit hashes for versions
  source                         = "terraform-aws-modules/eks/aws"
  version                        = "~> 20.37.2"
  cluster_name                   = var.cluster_name
  cluster_version                = var.cluster_version  
  cluster_endpoint_public_access = true  

  

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    gameservers = {
      instance_types = local.gameservers_instance_types
      ami_type       = local.gameservers_ami_type
      min_size       = var.gameservers_min_size
      max_size       = var.gameservers_max_size
      desired_size   = var.gameservers_desired_size
      labels = {
        "agones.dev/agones-gameserver" = true
      }

      subnet_ids = local.gameservers_subnet_ids
    }

    agones_system = {
      instance_types = local.agones_system_instance_types
      ami_type       = local.agones_system_ami_type

      # To use disk_size, you must use a standard launch template. Otherwise the value is ignored.
      # Source: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest/submodules/eks-managed-node-group
      # use_custom_launch_template = false
      # disk_size      = var.agones_system_ebs_size
      labels = {
        "agones.dev/agones-system" = true
      }
      taint = {
        dedicated = {
          key    = "agones.dev/agones-system"
          value  = true
          effect = "NO_EXECUTE"
        }
      }
      min_size     = var.agones_system_min_size
      max_size     = var.agones_system_max_size
      desired_size = var.agones_system_desired_size

      subnet_ids = slice(module.vpc.private_subnets, 0, 3)

    }
    agones_metrics = {
      instance_types = local.agones_metrics_instance_types
      ami_type       = local.agones_metrics_ami_type
      labels = {
        "agones.dev/agones-metrics" = true
      }
      taints = {
        dedicated = {
          key    = "agones.dev/agones-metrics"
          value  = true
          effect = "NO_EXECUTE"
        }
      }
      min_size     = var.agones_metrics_min_size
      max_size     = var.agones_metrics_max_size
      desired_size = var.agones_metrics_desired_size

      subnet_ids = slice(module.vpc.private_subnets, 0, 3)
    }

    open_match = {
      instance_types = local.open_match_instance_types
      ami_type       = local.open_match_ami_type
      labels = {
        "openmatch" = "system"
      }
      min_size     = var.open_match ? var.open_match_min_size : 0
      max_size     = var.open_match ? var.open_match_max_size : 1 # max_size can't be zero
      desired_size = var.open_match ? var.open_match_desired_size : 0

      subnet_ids = slice(module.vpc.private_subnets, 0, 3)
    }
    agones_openmatch = {
      instance_types = local.agones_open_match_instance_types
      ami_type       = local.agones_open_match_ami_type
      labels = {
        "openmatch" = "customization"
      }
      min_size     = var.open_match ? var.agones_openmatch_min_size : 0
      max_size     = var.open_match ? var.agones_openmatch_max_size : 1 # max_size can't be zero
      desired_size = var.open_match ? var.agones_openmatch_desired_size : 0

      subnet_ids = slice(module.vpc.private_subnets, 0, 3)
    }
  }

  # Keep create_kms_key as true (or omit it, as it's true by default)
  create_kms_key = true  

  # Customize the implicitly created KMS key that is created by Terraform
  kms_key_administrators          = concat([data.aws_caller_identity.current.arn], var.admin_role_arn != "" ? [var.admin_role_arn] : [], var.codebuild_role_arn != "" ? [var.codebuild_role_arn] : [])    
  kms_key_description             = "KMS Encryption Key for EKS Cluster"
  kms_key_deletion_window_in_days = 30
  enable_kms_key_rotation         = true

  eks_managed_node_group_defaults = {
    iam_role_additional_policies = {
      AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    }
  }
  node_security_group_additional_rules = {
    ingress_gameserver_udp = {
      description      = "Agones Game Server UDP Ports"
      protocol         = "udp"
      from_port        = var.gameserver_minport
      to_port          = var.gameserver_maxport
      type             = "ingress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    },
    ingress_gameserver_tcp = {
      description      = "Agones Game Server TCP Ports"
      protocol         = "tcp"
      from_port        = var.gameserver_minport
      to_port          = var.gameserver_maxport
      type             = "ingress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    },
    ingress_gameserver_webhook = {
      description                   = "Cluster API to node 8081/tcp agones webhook"
      protocol                      = "tcp"
      from_port                     = 8081
      to_port                       = 8081
      type                          = "ingress"
      source_cluster_security_group = true
    }

  }

 authentication_mode = "API_AND_CONFIG_MAP"
  access_entries = {
    # Only create blueprint_admin entry
    blueprint_admin = {
      kubernetes_groups = ["cluster-admin"]
      principal_arn    = module.eks_blueprints_admin_team.aws_auth_configmap_role.rolearn
      username         = module.eks_blueprints_admin_team.aws_auth_configmap_role.username
    }
  }


  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  #checkov:skip=CKV_TF_1:Module registry does not support commit hashes for versions
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.cluster_name
  cidr = var.cluster_cidr

  azs                     = local.azs
  private_subnets         = concat([for k, v in local.azs : cidrsubnet(var.cluster_cidr, 6, k)],
    [for k, v in local.azs : cidrsubnet(var.cluster_cidr, 8, k + 8)],
    [for k, v in local.azs : cidrsubnet(var.cluster_cidr, 8, k + 16)],
    [for k, v in local.azs : cidrsubnet(var.cluster_cidr, 8, k + 24)],
    [for k, v in local.azs : cidrsubnet(var.cluster_cidr, 8, k + 32)]
  )
  public_subnets          = [for k, v in local.azs : cidrsubnet(var.cluster_cidr, 8, k + 56)]
  map_public_ip_on_launch = true

  enable_nat_gateway = true
  single_nat_gateway = true

  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${var.cluster_name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${var.cluster_name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${var.cluster_name}-default" }


  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}


module "eks_blueprints_admin_team" {
  #checkov:skip=CKV_TF_1:Module registry does not support commit hashes for versions
  source  = "aws-ia/eks-blueprints-teams/aws"
  version = "~> 1.0"

  name = "admin-team"

  enable_admin = true
  users = concat(
    [data.aws_caller_identity.current.arn], # Adds the current user running Terraform (e.g. Administrator, CodeBuild, etc. )
    var.admin_role_arn != "" ? [var.admin_role_arn] : [] # Adds an optional Admin user ARN (Ideal for when Terraform is being run by CodeBuild as the current user)
  )
  cluster_arn  = module.eks.cluster_arn

  tags = local.tags
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}

resource "null_resource" "kubectl" {
  depends_on = [module.eks]
  provisioner "local-exec" {
    command = "aws eks --region ${var.cluster_region}  update-kubeconfig --name ${var.cluster_name}"
  }
}

# Add admin role using eksctl as a fallback
resource "null_resource" "update_aws_auth_eksctl" {
  # Only run this if admin_role_arn is provided
  count = var.admin_role_arn != "" ? 1 : 0
  
  depends_on = [null_resource.kubectl]

  provisioner "local-exec" {
    command = <<-EOT
      # Extract role name from ARN
      ROLE_NAME=$(echo "${var.admin_role_arn}" | sed 's/.*role\///')
      
      # Check if eksctl is installed
      if command -v eksctl &> /dev/null; then
        eksctl create iamidentitymapping \
          --cluster ${var.cluster_name} \
          --region ${var.cluster_region} \
          --arn ${var.admin_role_arn} \
          --group system:masters \
          --username $ROLE_NAME
      else
        echo "eksctl not found, skipping direct iamidentitymapping creation"
      fi
    EOT
  }
}
