## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0

provider "aws" {
  region = var.cluster_region
}

locals {
  repo_root          = "${path.module}/../.."
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
      args = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.cluster_region]
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
    args = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.cluster_region]
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
    command = "${path.module}/../../scripts/namespace-finalizer.sh ${each.key}"
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
  aws_for_fluentbit                   = { 
    set = [{
      name = "cloudWatchLogs.autoCreateGroup"
      value = true
    }]
  }
  enable_metrics_server               = true
  enable_aws_cloudwatch_metrics       = true
  enable_aws_for_fluentbit            = true
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    set = [{
      name  = "enableServiceMutatorWebhook"
      value = "false"
    }]
  }
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
  version          = "1.47.0"
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

#  set {
#    name = "agones.controller.labels.agones-controller"
#    value = "true"
#    type  = "string"
#  }

  set {
    name = "agones.extensions.nodeSelector.agones\\.dev/agones-system"
    value = "true"
    type  = "string"
  }

  set {
    name = "agones.ping.nodeSelector.agones\\.dev/agones-system"
    value = "true"
    type  = "string"
  }

  set {
    name = "agones.allocator.nodeSelector.agones\\.dev/agones-system"
    value = "true"
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
  version          = "1.8.1"
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

  set {
    name = "redis.master.nodeSelector"
    value = "\\{\"openmatch\": \"system\"\\}"
  }

  set {
    name  = "redis.image.tag"
    value = "latest"
  }

  set {
    name  = "redis.metrics.image.tag"
    value = "latest"
  }

  set {
    name  = "redis.sysctl.image.tag"
    value = "latest"
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
    command = "nohup ${local.repo_root}/scripts/configure-agones-tls.sh ${local.name} ${local.repo_root}&"
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
    command = "nohup ${local.repo_root}/scripts/generate-tls-files.sh ${var.cluster_name} ${local.repo_root} &"
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
    command = "nohup ${local.repo_root}/scripts/configure-open-match-ingress.sh ${var.cluster_name} ${local.repo_root} &"
  }

  depends_on = [
    helm_release.open-match,
    null_resource.agones_tls_configuration
  ]
}

################################################################################
# Open Match TLS Hardening (GODEBUG=tls3des=0)
# Open Match 1.8.1 is compiled with Go 1.21 which may still offer 3DES cipher
# suites. The Helm chart does not support env var injection, so we patch the
# deployments post-install to explicitly disable 3DES.
################################################################################
resource "null_resource" "open_match_tls_hardening" {
  count = var.configure_open_match ? 1 : 0
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    when    = create
    command = <<-EOT
      kubectl config use-context $(kubectl config get-contexts -o=name | grep "/${var.cluster_name}$") && \
      kubectl set env deployment/open-match-frontend -n open-match GODEBUG=tls3des=0 && \
      kubectl set env deployment/open-match-backend -n open-match GODEBUG=tls3des=0 && \
      kubectl set env deployment/open-match-query -n open-match GODEBUG=tls3des=0
    EOT
  }

  depends_on = [
    helm_release.open-match,
    null_resource.open_match_ingress_configuration
  ]
}

resource "null_resource" "generate_agones_certs" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    when    = create
    command = "nohup ${local.repo_root}/scripts/generate-agones-certs.sh ${var.cluster_name} ${local.repo_root} &"
  }

  depends_on = [
    module.eks_blueprints_addons,
    kubernetes_namespace.this
  ]
}

