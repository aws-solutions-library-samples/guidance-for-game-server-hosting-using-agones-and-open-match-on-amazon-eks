## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
# set -o xtrace
echo "#####"
NAMESPACE=agones-system
GAMESERVER_NAMESPACE=gameservers
CLUSTER_NAME1=$1
REGION1=$2
CLUSTER_NAME2=$3
REGION2=$4
KEY_FILE=client_${CLUSTER_NAME1}.key
CERT_FILE=client_${CLUSTER_NAME1}.crt
TLS_CA_FILE=ca_${CLUSTER_NAME1}.crt
kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER_NAME1})
EXTERNAL_IP=$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
ENDPOINT=https://${EXTERNAL_IP}/gameserverallocation
echo "- Allocating server -"
curl ${ENDPOINT} --key ${KEY_FILE} --cert ${CERT_FILE} --cacert ${TLS_CA_FILE} -H "Content-Type: application/json" --data '{"namespace":"'${NAMESPACE}'", "multiClusterSetting":{"enabled":true}}'
echo
echo "- Display ALLOCATED game servers on cluster ${CLUSTER_NAME1} only -"
kubectl get gameservers --namespace ${GAMESERVER_NAMESPACE} | grep Allocated
kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER_NAME2})
echo "- Display ALLOCATED game servers on cluster ${CLUSTER_NAME2} only -"
kubectl get gameservers --namespace ${GAMESERVER_NAMESPACE} | grep Allocated
