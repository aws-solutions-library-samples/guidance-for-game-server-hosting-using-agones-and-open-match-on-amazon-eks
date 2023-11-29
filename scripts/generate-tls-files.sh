## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
set -o xtrace
export CLUSTER_NAME=$1
export ROOT_PATH=$2
kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER_NAME})
KEY_FILE=${ROOT_PATH}/client_${CLUSTER_NAME}.key
CERT_FILE=${ROOT_PATH}/client_${CLUSTER_NAME}.crt
TLS_CA_FILE=${ROOT_PATH}/ca_${CLUSTER_NAME}.crt
kubectl get secret allocator-client.default -n default -o jsonpath="{.data.tls\.crt}" | base64 -d > "${CERT_FILE}"
kubectl get secret allocator-client.default -n default -o jsonpath="{.data.tls\.key}" | base64 -d > "${KEY_FILE}"
kubectl get secret allocator-tls-ca -n agones-system -o jsonpath="{.data.tls-ca\.crt}" | base64 -d > "${TLS_CA_FILE}"