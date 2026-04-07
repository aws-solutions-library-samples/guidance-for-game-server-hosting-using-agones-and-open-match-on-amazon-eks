#!/usr/bin/env bash
## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TFVARS_FILE="${TFVARS_FILE:-${REPO_ROOT}/agones.tfvars}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  deploy   Deploy all three Terraform stages (cluster, intra-cluster, extra-cluster)
  destroy  Tear down all three stages in reverse order

Configuration:
  Create agones.tfvars in the repo root (see agones.tfvars.example).
  Override with: TFVARS_FILE=/path/to/file $(basename "$0") deploy

Environment:
  AWS_PROFILE  AWS CLI profile to use (e.g. export AWS_PROFILE=demo)
EOF
  exit 1
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log() { echo "==> $*"; }
err() { printf "ERROR: %s\n" "$*" >&2; exit 1; }

# Read a key=value pair from the tfvars file (strips quotes and spaces)
tfvar() {
  local key="$1"
  local val
  val=$(grep -E "^${key}\s*=" "$TFVARS_FILE" | head -1 | cut -d= -f2- | tr -d ' "'\''')
  if [[ -z "$val" ]]; then
    err "Variable '${key}' not found in ${TFVARS_FILE}"
  fi
  echo "$val"
}

# Read a terraform output from a given stage directory.
# Fails loudly if the output is empty (prevents silent bad -var values).
tf_out() {
  local dir="$1" key="$2"
  local val
  val=$(terraform -chdir="$dir" output -raw "$key" 2>/dev/null)
  if [[ -z "$val" ]]; then
    err "Terraform output '${key}' from ${dir} is empty or missing"
  fi
  echo "$val"
}

tf_out_json() {
  local dir="$1" key="$2"
  local val
  val=$(terraform -chdir="$dir" output -json "$key" 2>/dev/null)
  if [[ -z "$val" ]]; then
    err "Terraform output '${key}' from ${dir} is empty or missing"
  fi
  echo "$val"
}

# ---------------------------------------------------------------------------
# Load config
# ---------------------------------------------------------------------------

load_config() {
  if [[ ! -f "$TFVARS_FILE" ]]; then
    err "Config file not found: ${TFVARS_FILE} -- Copy agones.tfvars.example to agones.tfvars and fill in your values."
  fi

  CLUSTER1=$(tfvar cluster_1_name)
  REGION1=$(tfvar cluster_1_region)
  CIDR1=$(tfvar cluster_1_cidr)
  CLUSTER2=$(tfvar cluster_2_name)
  REGION2=$(tfvar cluster_2_region)
  CIDR2=$(tfvar cluster_2_cidr)
  VERSION=$(tfvar cluster_version)

  CLUSTER_DIR="${REPO_ROOT}/terraform/cluster"
  INTRA_DIR="${REPO_ROOT}/terraform/intra-cluster"
  EXTRA_DIR="${REPO_ROOT}/terraform/extra-cluster"
}

# ---------------------------------------------------------------------------
# Deploy
# ---------------------------------------------------------------------------

deploy_cluster() {
  log "Stage 1/3: Creating EKS clusters"
  terraform -chdir="$CLUSTER_DIR" init -input=false
  terraform -chdir="$CLUSTER_DIR" apply -auto-approve \
    -var="cluster_1_name=${CLUSTER1}" \
    -var="cluster_1_region=${REGION1}" \
    -var="cluster_1_cidr=${CIDR1}" \
    -var="cluster_2_name=${CLUSTER2}" \
    -var="cluster_2_region=${REGION2}" \
    -var="cluster_2_cidr=${CIDR2}" \
    -var="cluster_version=${VERSION}"
}

deploy_intra_cluster() {
  log "Stage 2/3: Deploying Helm charts (Agones, Open Match, addons)"

  # Ensure kubeconfig contexts exist for both clusters (needed by local-exec provisioners)
  aws eks --region "${REGION1}" update-kubeconfig --name "${CLUSTER1}"
  aws eks --region "${REGION2}" update-kubeconfig --name "${CLUSTER2}"

  terraform -chdir="$INTRA_DIR" init -input=false

  # Read cluster 1 outputs into variables (fails early if missing)
  local c1_endpoint c1_ca c1_token c1_oidc
  c1_endpoint=$(tf_out "$CLUSTER_DIR" cluster_1_endpoint)
  c1_ca=$(tf_out "$CLUSTER_DIR" cluster_1_certificate_authority_data)
  c1_token=$(tf_out "$CLUSTER_DIR" cluster_1_token)
  c1_oidc=$(tf_out "$CLUSTER_DIR" oidc_provider_1_arn)

  log "  Deploying to cluster 1 (${CLUSTER1} / ${REGION1})"
  terraform -chdir="$INTRA_DIR" workspace select -or-create=true "${REGION1}"
  terraform -chdir="$INTRA_DIR" apply -auto-approve \
    -var="cluster_name=${CLUSTER1}" \
    -var="cluster_region=${REGION1}" \
    -var="cluster_endpoint=${c1_endpoint}" \
    -var="cluster_certificate_authority_data=${c1_ca}" \
    -var="cluster_token=${c1_token}" \
    -var="cluster_version=${VERSION}" \
    -var="oidc_provider_arn=${c1_oidc}" \
    -var='namespaces=["agones-openmatch", "agones-system", "gameservers", "open-match"]' \
    -var="configure_agones=true" \
    -var="configure_open_match=true"

  # Read cluster 2 outputs into variables (fails early if missing)
  local c2_endpoint c2_ca c2_token c2_oidc
  c2_endpoint=$(tf_out "$CLUSTER_DIR" cluster_2_endpoint)
  c2_ca=$(tf_out "$CLUSTER_DIR" cluster_2_certificate_authority_data)
  c2_token=$(tf_out "$CLUSTER_DIR" cluster_2_token)
  c2_oidc=$(tf_out "$CLUSTER_DIR" oidc_provider_2_arn)

  log "  Deploying to cluster 2 (${CLUSTER2} / ${REGION2})"
  terraform -chdir="$INTRA_DIR" workspace select -or-create=true "${REGION2}"
  terraform -chdir="$INTRA_DIR" apply -auto-approve \
    -var="cluster_name=${CLUSTER2}" \
    -var="cluster_region=${REGION2}" \
    -var="cluster_endpoint=${c2_endpoint}" \
    -var="cluster_certificate_authority_data=${c2_ca}" \
    -var="cluster_token=${c2_token}" \
    -var="cluster_version=${VERSION}" \
    -var="oidc_provider_arn=${c2_oidc}" \
    -var='namespaces=["agones-system", "gameservers"]' \
    -var="configure_agones=true" \
    -var="configure_open_match=false"
}

deploy_extra_cluster() {
  log "Stage 3/3: ECR, VPC peering, Global Accelerator"
  terraform -chdir="$EXTRA_DIR" init -input=false

  # Look up the Open Match Frontend load balancer ARN
  log "  Looking up Open Match Frontend load balancer ARN"
  aws eks --region "${REGION1}" update-kubeconfig --name "${CLUSTER1}"
  kubectl config use-context "$(kubectl config get-contexts -o=name | grep -E "/${CLUSTER1}$" | head -1)"

  local om_svc_name="${CLUSTER1}-om-fe"
  local flb_name
  flb_name=$(kubectl get services -n open-match -o json \
    | jq -r --arg SVC "$om_svc_name" '.items[] | select(.metadata.name==$SVC) | .status.loadBalancer.ingress[0].hostname')

  if [[ -z "$flb_name" ]] || [[ "$flb_name" == "null" ]]; then
    err "Could not find load balancer hostname for Open Match Frontend service (${om_svc_name})"
  fi

  local flb_arn
  flb_arn=$(aws elbv2 describe-load-balancers --region "${REGION1}" \
    | jq -r --arg DNS "$flb_name" '.LoadBalancers[] | select(.DNSName==$DNS) | .LoadBalancerArn')

  if [[ -z "$flb_arn" ]]; then
    err "Could not find load balancer ARN for Open Match Frontend (${om_svc_name})"
  fi
  log "  Found LB ARN: ${flb_arn}"

  # Read all cluster outputs into variables (fails early if missing)
  local vpc1 route1 gs1_subnets c1_ep c1_ca c1_tok
  vpc1=$(tf_out "$CLUSTER_DIR" vpc_1_id)
  route1=$(tf_out "$CLUSTER_DIR" private_route_table_1_id)
  gs1_subnets=$(tf_out_json "$CLUSTER_DIR" gameservers_1_subnets)
  c1_ep=$(tf_out "$CLUSTER_DIR" cluster_1_endpoint)
  c1_ca=$(tf_out "$CLUSTER_DIR" cluster_1_certificate_authority_data)
  c1_tok=$(tf_out "$CLUSTER_DIR" cluster_1_token)

  local vpc2 route2 gs2_subnets c2_ep c2_ca c2_tok
  vpc2=$(tf_out "$CLUSTER_DIR" vpc_2_id)
  route2=$(tf_out "$CLUSTER_DIR" private_route_table_2_id)
  gs2_subnets=$(tf_out_json "$CLUSTER_DIR" gameservers_2_subnets)
  c2_ep=$(tf_out "$CLUSTER_DIR" cluster_2_endpoint)
  c2_ca=$(tf_out "$CLUSTER_DIR" cluster_2_certificate_authority_data)
  c2_tok=$(tf_out "$CLUSTER_DIR" cluster_2_token)

  terraform -chdir="$EXTRA_DIR" apply -auto-approve \
    -var="cluster_1_name=${CLUSTER1}" \
    -var="cluster_1_region=${REGION1}" \
    -var="ecr_region=${REGION1}" \
    -var="cluster_2_name=${CLUSTER2}" \
    -var="cluster_2_region=${REGION2}" \
    -var="requester_cidr=${CIDR1}" \
    -var="requester_vpc_id=${vpc1}" \
    -var="requester_route=${route1}" \
    -var="cluster_1_gameservers_subnets=${gs1_subnets}" \
    -var="cluster_1_endpoint=${c1_ep}" \
    -var="cluster_1_certificate_authority_data=${c1_ca}" \
    -var="cluster_1_token=${c1_tok}" \
    -var="accepter_cidr=${CIDR2}" \
    -var="accepter_vpc_id=${vpc2}" \
    -var="accepter_route=${route2}" \
    -var="cluster_2_gameservers_subnets=${gs2_subnets}" \
    -var="cluster_2_endpoint=${c2_ep}" \
    -var="cluster_2_certificate_authority_data=${c2_ca}" \
    -var="cluster_2_token=${c2_tok}" \
    -var="aws_lb_arn=${flb_arn}"
}

do_deploy() {
  deploy_cluster
  deploy_intra_cluster
  deploy_extra_cluster
  log "Deploy complete!"
  terraform -chdir="$EXTRA_DIR" output
}

# ---------------------------------------------------------------------------
# Destroy
# ---------------------------------------------------------------------------

destroy_extra_cluster() {
  log "Stage 1/3: Destroying extra-cluster (ECR, VPC peering, Global Accelerator)"

  # Check if extra-cluster has state to destroy
  if [[ ! -f "${EXTRA_DIR}/terraform.tfstate" ]] && [[ ! -d "${EXTRA_DIR}/.terraform" ]]; then
    log "  No extra-cluster state found, skipping"
    return 0
  fi

  terraform -chdir="$EXTRA_DIR" init -input=false

  # If state is empty, nothing to destroy
  local resource_count
  resource_count=$(terraform -chdir="$EXTRA_DIR" state list 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$resource_count" -eq 0 ]]; then
    log "  Extra-cluster state is empty, skipping"
    return 0
  fi

  # Read all cluster outputs into variables (fails early if missing)
  local vpc1 route1 gs1_subnets c1_ep c1_ca c1_tok
  vpc1=$(tf_out "$CLUSTER_DIR" vpc_1_id)
  route1=$(tf_out "$CLUSTER_DIR" private_route_table_1_id)
  gs1_subnets=$(tf_out_json "$CLUSTER_DIR" gameservers_1_subnets)
  c1_ep=$(tf_out "$CLUSTER_DIR" cluster_1_endpoint)
  c1_ca=$(tf_out "$CLUSTER_DIR" cluster_1_certificate_authority_data)
  c1_tok=$(tf_out "$CLUSTER_DIR" cluster_1_token)

  local vpc2 route2 gs2_subnets c2_ep c2_ca c2_tok
  vpc2=$(tf_out "$CLUSTER_DIR" vpc_2_id)
  route2=$(tf_out "$CLUSTER_DIR" private_route_table_2_id)
  gs2_subnets=$(tf_out_json "$CLUSTER_DIR" gameservers_2_subnets)
  c2_ep=$(tf_out "$CLUSTER_DIR" cluster_2_endpoint)
  c2_ca=$(tf_out "$CLUSTER_DIR" cluster_2_certificate_authority_data)
  c2_tok=$(tf_out "$CLUSTER_DIR" cluster_2_token)

  # aws_lb_arn is not needed during destroy; provide a placeholder
  terraform -chdir="$EXTRA_DIR" destroy -auto-approve \
    -var="cluster_1_name=${CLUSTER1}" \
    -var="cluster_1_region=${REGION1}" \
    -var="ecr_region=${REGION1}" \
    -var="cluster_2_name=${CLUSTER2}" \
    -var="cluster_2_region=${REGION2}" \
    -var="requester_cidr=${CIDR1}" \
    -var="requester_vpc_id=${vpc1}" \
    -var="requester_route=${route1}" \
    -var="cluster_1_gameservers_subnets=${gs1_subnets}" \
    -var="cluster_1_endpoint=${c1_ep}" \
    -var="cluster_1_certificate_authority_data=${c1_ca}" \
    -var="cluster_1_token=${c1_tok}" \
    -var="accepter_cidr=${CIDR2}" \
    -var="accepter_vpc_id=${vpc2}" \
    -var="accepter_route=${route2}" \
    -var="cluster_2_gameservers_subnets=${gs2_subnets}" \
    -var="cluster_2_endpoint=${c2_ep}" \
    -var="cluster_2_certificate_authority_data=${c2_ca}" \
    -var="cluster_2_token=${c2_tok}" \
    -var="aws_lb_arn=destroy-placeholder"
}

destroy_intra_cluster() {
  log "Stage 2/3: Destroying intra-cluster (Helm charts, addons)"

  # Check if intra-cluster has been initialized
  if [[ ! -d "${INTRA_DIR}/.terraform" ]] && [[ ! -d "${INTRA_DIR}/terraform.tfstate.d" ]]; then
    log "  No intra-cluster state found, skipping"
    return 0
  fi

  terraform -chdir="$INTRA_DIR" init -input=false

  # Destroy cluster 2 workspace first (no Open Match dependency)
  if terraform -chdir="$INTRA_DIR" workspace select "${REGION2}" 2>/dev/null; then
    local rc2
    rc2=$(terraform -chdir="$INTRA_DIR" state list 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$rc2" -eq 0 ]]; then
      log "  Workspace ${REGION2} state is empty, skipping"
    else
      local c2_ep c2_ca c2_tok c2_oidc
      c2_ep=$(tf_out "$CLUSTER_DIR" cluster_2_endpoint)
      c2_ca=$(tf_out "$CLUSTER_DIR" cluster_2_certificate_authority_data)
      c2_tok=$(tf_out "$CLUSTER_DIR" cluster_2_token)
      c2_oidc=$(tf_out "$CLUSTER_DIR" oidc_provider_2_arn)

      log "  Destroying cluster 2 (${CLUSTER2} / ${REGION2})"
      terraform -chdir="$INTRA_DIR" destroy -auto-approve \
      -var="cluster_name=${CLUSTER2}" \
      -var="cluster_region=${REGION2}" \
      -var="cluster_endpoint=${c2_ep}" \
      -var="cluster_certificate_authority_data=${c2_ca}" \
      -var="cluster_token=${c2_tok}" \
      -var="cluster_version=${VERSION}" \
      -var="oidc_provider_arn=${c2_oidc}" \
      -var='namespaces=["agones-system", "gameservers"]' \
      -var="configure_agones=true" \
      -var="configure_open_match=false"
    fi
  else
    log "  No workspace for ${REGION2}, skipping"
  fi

  # Destroy cluster 1 workspace
  if terraform -chdir="$INTRA_DIR" workspace select "${REGION1}" 2>/dev/null; then
    local rc1
    rc1=$(terraform -chdir="$INTRA_DIR" state list 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$rc1" -eq 0 ]]; then
      log "  Workspace ${REGION1} state is empty, skipping"
    else
      local c1_ep c1_ca c1_tok c1_oidc
      c1_ep=$(tf_out "$CLUSTER_DIR" cluster_1_endpoint)
      c1_ca=$(tf_out "$CLUSTER_DIR" cluster_1_certificate_authority_data)
      c1_tok=$(tf_out "$CLUSTER_DIR" cluster_1_token)
      c1_oidc=$(tf_out "$CLUSTER_DIR" oidc_provider_1_arn)

      log "  Destroying cluster 1 (${CLUSTER1} / ${REGION1})"
      terraform -chdir="$INTRA_DIR" destroy -auto-approve \
        -var="cluster_name=${CLUSTER1}" \
        -var="cluster_region=${REGION1}" \
        -var="cluster_endpoint=${c1_ep}" \
        -var="cluster_certificate_authority_data=${c1_ca}" \
        -var="cluster_token=${c1_tok}" \
        -var="cluster_version=${VERSION}" \
        -var="oidc_provider_arn=${c1_oidc}" \
        -var='namespaces=["agones-openmatch", "agones-system", "gameservers", "open-match"]' \
        -var="configure_agones=true" \
        -var="configure_open_match=true"
    fi
  else
    log "  No workspace for ${REGION1}, skipping"
  fi
}

cleanup_load_balancers() {
  # Kubernetes-created load balancers (Agones allocator/ping, Open Match Frontend)
  # are not managed by Terraform. If the AWS Load Balancer Controller is destroyed
  # before it can clean them up, they orphan ENIs in the VPC subnets, blocking
  # VPC deletion. Delete any remaining ELBs/NLBs in both VPCs before cluster destroy.
  log "  Cleaning up Kubernetes-created load balancers"

  local any_deleted=false

  for region_var in REGION1 REGION2; do
    local region="${!region_var}"
    local vpc_num="${region_var: -1}"
    local vpc_id
    vpc_id=$(tf_out "$CLUSTER_DIR" "vpc_${vpc_num}_id" 2>/dev/null) || continue

    if [[ -z "$vpc_id" ]]; then
      log "    Skipping ${region}: could not determine VPC ID"
      continue
    fi

    # Classic ELBs (Open Match Frontend uses this type)
    local elbs
    elbs=$(aws elb describe-load-balancers --region "$region" \
      --query "LoadBalancerDescriptions[?VPCId==\`${vpc_id}\`].LoadBalancerName" \
      --output text 2>/dev/null) || true
    for elb in $elbs; do
      log "    Deleting Classic ELB: ${elb} (${region})"
      aws elb delete-load-balancer --region "$region" --load-balancer-name "$elb" || true
      any_deleted=true
    done

    # elbv2 NLBs/ALBs (Agones allocator, ping)
    local nlbs
    nlbs=$(aws elbv2 describe-load-balancers --region "$region" \
      --query "LoadBalancers[?VpcId==\`${vpc_id}\`].LoadBalancerArn" \
      --output text 2>/dev/null) || true
    for nlb in $nlbs; do
      log "    Deleting NLB/ALB: ${nlb} (${region})"
      aws elbv2 delete-load-balancer --region "$region" --load-balancer-arn "$nlb" || true
      any_deleted=true
    done
  done

  if [[ "$any_deleted" == "true" ]]; then
    log "  Waiting 60s for ENI cleanup after load balancer deletion"
    sleep 60
  fi

  # Clean up orphaned security groups created by the Kubernetes AWS LB controller.
  # These follow the naming convention k8s-* and are not managed by Terraform.
  for region_var in REGION1 REGION2; do
    local region="${!region_var}"
    local vpc_num="${region_var: -1}"
    local vpc_id
    vpc_id=$(tf_out "$CLUSTER_DIR" "vpc_${vpc_num}_id" 2>/dev/null) || continue

    if [[ -z "$vpc_id" ]]; then
      continue
    fi

    local sgs
    sgs=$(aws ec2 describe-security-groups --region "$region" \
      --filters "Name=vpc-id,Values=${vpc_id}" "Name=group-name,Values=k8s-*" \
      --query 'SecurityGroups[].GroupId' --output text 2>/dev/null) || true
    for sg in $sgs; do
      log "    Deleting orphaned k8s security group: ${sg} (${region})"
      aws ec2 delete-security-group --region "$region" --group-id "$sg" || true
    done
  done
}

destroy_cluster() {
  log "Stage 3/3: Destroying EKS clusters"

  if [[ ! -f "${CLUSTER_DIR}/terraform.tfstate" ]] && [[ ! -d "${CLUSTER_DIR}/.terraform" ]]; then
    log "  No cluster state found, skipping"
    return 0
  fi

  cleanup_load_balancers

  terraform -chdir="$CLUSTER_DIR" init -input=false
  terraform -chdir="$CLUSTER_DIR" destroy -auto-approve \
    -var="cluster_1_name=${CLUSTER1}" \
    -var="cluster_1_region=${REGION1}" \
    -var="cluster_1_cidr=${CIDR1}" \
    -var="cluster_2_name=${CLUSTER2}" \
    -var="cluster_2_region=${REGION2}" \
    -var="cluster_2_cidr=${CIDR2}" \
    -var="cluster_version=${VERSION}"
}

do_destroy() {
  destroy_extra_cluster
  destroy_intra_cluster
  destroy_cluster
  log "Destroy complete!"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

[[ $# -lt 1 ]] && usage
load_config

case "$1" in
  deploy)  do_deploy ;;
  destroy) do_destroy ;;
  *)       usage ;;
esac
