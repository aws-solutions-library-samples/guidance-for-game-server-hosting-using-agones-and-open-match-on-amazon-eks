## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
CLUSTER_NAME=$1
kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER_NAME}) 2>&1 > /dev/null
ALLOCATOR_IP=$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo ${ALLOCATOR_IP}
