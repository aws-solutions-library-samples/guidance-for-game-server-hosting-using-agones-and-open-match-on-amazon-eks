## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
set -o xtrace
export CLUSTER1=$1
export CLUSTER2=$2
export ROOT_PATH=$3
kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER2})
export ALLOCATOR_IP_CLUSTER2=$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER1})
export ALLOCATOR_IP_CLUSTER1=$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
kubectl apply -f ${ROOT_PATH}/manifests/multicluster-allocation-1.yaml
envsubst < ${ROOT_PATH}/manifests/multicluster-allocation-1-to-2.yaml | kubectl apply -f -
# kubectl delete secret allocator-secret-to-cluster-2 -n agones-system
kubectl create secret generic \
--from-file=tls.crt=${ROOT_PATH}/client_agones-gameservers-2.crt \
--from-file=tls.key=${ROOT_PATH}/client_agones-gameservers-2.key \
--from-file=ca.crt=${ROOT_PATH}/ca_agones-gameservers-2.crt \
allocator-secret-to-cluster-2 -n agones-system