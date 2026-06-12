## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
CLUSTER_NAME=$1
CONTEXT=$(kubectl config get-contexts -o=name | grep "/${CLUSTER_NAME}$" | head -1)
if [ -z "$CONTEXT" ]; then
  echo "ERROR: No kubectl context found matching cluster '${CLUSTER_NAME}'." >&2
  exit 1
fi
kubectl config use-context "$CONTEXT" > /dev/null 2>&1
ALLOCATOR_IP=$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo ${ALLOCATOR_IP}
