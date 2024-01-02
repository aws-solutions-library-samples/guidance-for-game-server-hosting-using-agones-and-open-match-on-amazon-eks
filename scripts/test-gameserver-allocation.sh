## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
# set -o xtrace
echo "#####"
NAMESPACE=gameservers
CLUSTER_NAME=$1
REGION=$2
kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER_NAME})
KEY_FILE=client_${CLUSTER_NAME}.key
CERT_FILE=client_${CLUSTER_NAME}.crt
TLS_CA_FILE=ca_${CLUSTER_NAME}.crt
EXTERNAL_IP=$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
ENDPOINT=https://${EXTERNAL_IP}/gameserverallocation
echo "- Allocating server -"
curl ${ENDPOINT} --key ${KEY_FILE} --cert ${CERT_FILE} --cacert ${TLS_CA_FILE} -H "Content-Type: application/json" --data '{"namespace":"'${NAMESPACE}'"}'
echo
echo "- Display game servers -"
kubectl get gameservers --namespace ${NAMESPACE} --show-labels
