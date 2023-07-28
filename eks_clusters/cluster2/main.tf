provider "aws" {
  alias = "ecr"
  region = local.ecr_region
}

provider "aws" {
  region = local.cluster_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.ecr
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}

locals {
  #name   = basename(path.cwd)
  name = var.cluster_name
  cluster_region = var.cluster_region
  ecr_region = var.ecr_region
  cluster_version = "1.24"
  gameserver_minport = 7000
  gameserver_maxport = 8000
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }
}

################################################################################
# Primary Cluster
################################################################################

#tfsec:ignore:aws-eks-enable-control-plane-logging
module "eks" {
  #checkov:skip=CKV_TF_1:Module registry does not support commit hashes for versions
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.13"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    initial = {
      instance_types = ["m5.large"]
      min_size     = 10
      max_size     = 15
      desired_size = 10
    }

    agones_system = {
      instance_types = ["m5.large"]
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
      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
    agones_metrics = {
      instance_types = ["m5.large"]
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
      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
  }

  node_security_group_additional_rules = {
    ingress_gameserver_udp = {
      description      = "Agones Game Server Ports"
      protocol         = "udp"
      from_port        = local.gameserver_minport
      to_port          = local.gameserver_maxport
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
  manage_aws_auth_configmap = true
  aws_auth_roles = flatten([
    module.eks_blueprints_admin_team.aws_auth_configmap_role
  ])

  tags = local.tags
}



resource "kubernetes_namespace" "this" {


  for_each = toset( var.namespaces )
  metadata {
    name = each.key
  }
  provisioner "local-exec" {

    when = destroy
    command    = "nohup ../../namespace-finalizer.sh ${each.key} 2>&1 &"
  }
}



################################################################################
# Kubernetes Addons
################################################################################

module "eks_blueprints_addons" {
  source = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0" #ensure to update this to the latest/desired version

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }


  # Opinions for our game servers cluster
  enable_metrics_server     = true
  enable_aws_cloudwatch_metrics = true
  enable_aws_for_fluentbit = true
  enable_aws_load_balancer_controller = true
  enable_cert_manager = true

  depends_on = [
    module.eks
  ]

}


################################################################################
# Agones Helm Chart
################################################################################
resource "helm_release" "agones" {
  name       = "agones"
  chart      = "agones"
  repository = "https://agones.dev/chart/stable"
  version    = "1.33.0"
  namespace  = "agones-system"
  create_namespace = false
  timeout = 1800
  wait = false


  values = [templatefile("./helm_values/agones-helm-values.yaml", {
    expose_udp            = true
    gameserver_namespaces = "{${join(",", ["default"])}}"
    gameserver_minport = local.gameserver_minport
    gameserver_maxport = local.gameserver_maxport
  })]

  depends_on = [
    module.eks,
    module.eks_blueprints_addons,
    null_resource.generate_agones_certs
  ]


}

################################################################################
# OpenMatch Helm Chart
################################################################################
resource "helm_release" "open-match" {
  name       = "open-match"
  chart      = "open-match"
  repository = "https://open-match.dev/chart/stable"
  version    = "1.7.0"
  namespace  = "open-match"
  create_namespace = false
  timeout = 1800
  wait = false

  set {
    name  = "open-match-customize.enabled"
    value = "true"
  }

  set {
    name  = "open-match-customize.evaluator.enabled"
    value = "true"
  }

  set {
    name  = "open-match-override.enabled"
    value = "true"
  }

  set {
    name  = "open-match-core.swaggerui.enabled"
    value = "true"
  }

  set {
    name  = "global.tls.enabled"
    value = "true"
  }

  depends_on = [
    module.eks,
    module.eks_blueprints_addons,
    null_resource.generate_agones_certs
  ]


}

resource "null_resource" "generate_agones_certs" {

  count = var.configure_agones ? 1 : 0

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    when = create
    command    = "nohup ../../scripts/generate-agones-certs.sh ${local.name} ${local.cluster_region}&"
  }

  depends_on = [
    module.eks,
    module.eks_blueprints_addons
  ]


}

resource "null_resource" "agones_tls_configuration" {

  count = var.configure_agones ? 1 : 0

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    when = create
    command    = "nohup ../../scripts/configure-agones-tls.sh ${local.name} ${local.cluster_region} &"
  }

  depends_on = [
    helm_release.agones
  ]

}

resource "null_resource" "open_match_ingress_configuration" {

  count = var.configure_open_match ? 1 : 0

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    when = create
    command    = "nohup ../../scripts/configure-open-match-ingress.sh ${local.name} ${local.cluster_region} &"
  }

  depends_on = [
    helm_release.open-match
  ]

}


################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  #checkov:skip=CKV_TF_1:Module registry does not support commit hashes for versions
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway   = true
  single_nat_gateway   = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}


module "eks_blueprints_admin_team" {
  source  = "aws-ia/eks-blueprints-teams/aws"
  version = "~> 1.0"

  name = "admin-team"

  enable_admin = true
  users        = [data.aws_caller_identity.current.arn]
  cluster_arn  = module.eks.cluster_arn

  tags = local.tags
}