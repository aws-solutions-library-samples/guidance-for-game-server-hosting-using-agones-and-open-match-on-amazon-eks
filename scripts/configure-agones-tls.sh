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
echo "- Verify that the Agones pods are running -"
kubectl get pods -n agones-system -o wide
export EXTERNAL_IP=$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "- Verify that the cert-manager pods are running -"
kubectl get pods -n cert-manager -o wide
echo "- Create a certificate for agones-allocator -"
envsubst < ${ROOT_PATH}/manifests/agones-allocator-tls.yaml | kubectl apply -f -
echo "- Wait and get the allocator-tls Secret -"
while ! kubectl get secret allocator-tls -n agones-system; do echo "Waiting for allocator-tls secret."; sleep 5; done
TLS_CA_VALUE=$(kubectl get secret allocator-tls -n agones-system -o jsonpath='{.data.ca\.crt}')
echo "- Add ca.crt to the allocator-tls-ca Secret -"
kubectl get secret allocator-tls-ca -o json -n agones-system | jq '.data["tls-ca.crt"]="'${TLS_CA_VALUE}'"' | kubectl apply -f -