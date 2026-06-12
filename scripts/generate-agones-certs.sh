## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
set -o xtrace
echo "#####"
CLUSTER_NAME=$1
ROOT_PATH=$2
CONTEXT=$(kubectl config get-contexts -o=name | grep "/${CLUSTER_NAME}$" | head -1)
if [ -z "$CONTEXT" ]; then
  echo "ERROR: No kubectl context found matching cluster '${CLUSTER_NAME}'." >&2
  kubectl config get-contexts -o=name >&2
  exit 1
fi
kubectl config use-context "$CONTEXT"
echo "- Verify that the cert-manager pods are running -"
kubectl get pods -n cert-manager -o wide
echo "- Verify the cert-manager webhook is available -"
kubectl wait deployment -l app=webhook --for condition=Available=True --timeout=90s -n cert-manager
echo "- Create the cluster issuer for cert-manager (used by allocator TLS) -"
kubectl apply -f ${ROOT_PATH}/manifests/cluster-issuer.yaml
# Controller/extensions now use Agones built-in TLS (generateTLS: true, disableSecret: false).
# Only the allocator still uses cert-manager (see configure-agones-tls.sh).

sleep 60