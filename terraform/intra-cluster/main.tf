## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0

provider "aws" {
  region = var.cluster_region
}

locals {
  name               = var.cluster_name
  cluster_region     = var.cluster_region
  gameserver_minport = 7000
  gameserver_maxport = 7029
}


provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
    # token                  = var.cluster_token
    # config_path            = "~/.kube/config"
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", var.cluster_name]
    }
  }
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  # token                  = var.cluster_token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", var.cluster_name]
  }
}


resource "kubernetes_namespace" "this" {
  #   provider = local.kubernetes_alias
  for_each = toset(var.namespaces)
  metadata {
    name = each.key
  }
  provisioner "local-exec" {

    when    = destroy
    command = "nohup ${path.cwd}/scripts/namespace-finalizer.sh ${each.key} 2>&1 &"
    # command = "nohup ${path.cwd}/scripts/namespace-finalizer.sh ${var.cluster_name} ${each.key} 2>&1 &"
  }
}


################################################################################
# Kubernetes Addons
################################################################################

module "eks_blueprints_addons" {
  #checkov:skip=CKV_TF_1:Module registry does not support commit hashes for versions
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0" #ensure to update this to the latest/desired version

  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn

  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          AWS_VPC_K8S_CNI_EXTERNALSNAT = "true"
      } })
    }
    kube-proxy = {
      most_recent = true
    }
  }


  # Opinions for our game servers cluster
  enable_metrics_server               = true
  enable_aws_cloudwatch_metrics       = true
  enable_aws_for_fluentbit            = true
  enable_aws_load_balancer_controller = true
  enable_cert_manager                 = true


}


################################################################################
# Agones Helm Chart
################################################################################
resource "helm_release" "agones" {
  #   provider = local.helm_alias
  name             = "agones"
  chart            = "agones"
  repository       = "https://agones.dev/chart/stable"
  version          = "1.36.0"
  namespace        = "agones-system"
  create_namespace = false
  timeout          = 1800
  wait             = false


  values = [templatefile("${path.root}/helm_values/agones-helm-values.yaml", {
    expose_udp            = true
    gameserver_namespaces = "{${join(",", ["default"])}}"
    gameserver_minport    = local.gameserver_minport
    gameserver_maxport    = local.gameserver_maxport
  })]

  set {
    name  = "agones.allocator.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-name"
    value = "${var.cluster_name}-allocator"
    type  = "string"
  }

  set {
    name  = "agones.ping.http.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-name"
    value = "${var.cluster_name}-ping-http"
    type  = "string"
  }

  set {
    name  = "agones.ping.udp.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-name"
    value = "${var.cluster_name}-ping-udp"
    type  = "string"
  }

  depends_on = [
    module.eks_blueprints_addons,
    kubernetes_namespace.this
    # null_resource.generate_agones_certs
  ]


}

################################################################################
# OpenMatch Helm Chart
################################################################################
resource "helm_release" "open-match" {
  #   provider = local.helm_alias
  count            = var.configure_open_match ? 1 : 0
  name             = "open-match"
  chart            = "open-match"
  repository       = "https://open-match.dev/chart/stable"
  version          = "1.8.0"
  namespace        = "open-match"
  create_namespace = false
  timeout          = 1800
  wait             = false

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

  set {
    name  = "global.kubernetes.nodeSelector.openmatch"
    value = "system"
  }

  depends_on = [
    module.eks_blueprints_addons,
    null_resource.generate_agones_certs,
    kubernetes_namespace.this
  ]
}



resource "null_resource" "agones_tls_configuration" {
  #   provider = local.kubernetes_alias

  count = var.configure_agones ? 1 : 0

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    when    = create
    command = "nohup ${path.cwd}/scripts/configure-agones-tls.sh ${local.name} ${path.cwd}&"
  }

  depends_on = [
    helm_release.agones,
    null_resource.generate_agones_certs
  ]
}


resource "null_resource" "allocator_tls_files" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    when    = create
    command = "nohup ${path.cwd}/scripts/generate-tls-files.sh ${var.cluster_name} ${path.cwd} &"
  }

  depends_on = [
    module.eks_blueprints_addons,
    null_resource.agones_tls_configuration
  ]

}


resource "null_resource" "open_match_ingress_configuration" {
  count = var.configure_open_match ? 1 : 0
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    when    = create
    command = "nohup ${path.cwd}/scripts/configure-open-match-ingress.sh ${var.cluster_name} ${path.cwd} &"
  }

  depends_on = [
    helm_release.open-match,
    null_resource.agones_tls_configuration
  ]
}

resource "null_resource" "generate_agones_certs" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    when    = create
    command = "nohup ${path.cwd}/scripts/generate-agones-certs.sh ${var.cluster_name} ${path.cwd} &"
  }

  depends_on = [
    module.eks_blueprints_addons,
    kubernetes_namespace.this
  ]
}


# Used to output the address of the Load Balancer created by null_resource.open_match_ingress_configuration
data "aws_lb" "frontend_lb" {
  count      = var.configure_open_match ? 1 : 0
  name       = "${var.cluster_name}-om-fe"
  depends_on = [null_resource.open_match_ingress_configuration]
}