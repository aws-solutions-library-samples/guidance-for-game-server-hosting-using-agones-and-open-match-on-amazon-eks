## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
export CLUSTER_NAME=$1
kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER_NAME})
KEY_FILE=client_${CLUSTER_NAME}.key
CERT_FILE=client_${CLUSTER_NAME}.crt
TLS_CA_FILE=ca_${CLUSTER_NAME}.crt
kubectl port-forward -nagones-system svc/agones-allocator 4443:443 &
PID=$! 
RESOLVE=agones-allocator.agones-system.svc.cluster.local:443:127.0.0.1
ENDPOINT=https://agones-allocator.agones-system.svc.cluster.local:4443/gameserverallocation
sleep 10
curl $2 --resolve ${RESOLVE} ${ENDPOINT} --key ${KEY_FILE} --cert ${CERT_FILE} --cacert ${TLS_CA_FILE} -H "Content-Type: application/json" --data '{"namespace":"'gameservers'"}'
echo
kill ${PID}