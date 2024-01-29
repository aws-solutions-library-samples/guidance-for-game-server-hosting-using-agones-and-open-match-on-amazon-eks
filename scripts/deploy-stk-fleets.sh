## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
export GAMESERVER_TYPE=stk 
export NAMESPACE=gameservers
export CLUSTER_NAME1=$1
export REGION1=$2
export CLUSTER_NAME2=$3
export REGION2=$4

echo "- Deploy fleets to cluster ${CLUSTER_NAME1} -"
for f in manifests/fleets/${GAMESERVER_TYPE}/*
do
    envsubst < $f  | kubectl apply --namespace ${NAMESPACE} -f -
done
echo
echo "- Display fleets and game servers -"
kubectl get fleets --namespace ${NAMESPACE}
kubectl get gameservers --namespace ${NAMESPACE} --show-labels
echo

kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER_NAME2})
export REGION=$REGION2
echo "- Deploy fleets to cluster ${CLUSTER_NAME2} -"
for f in manifests/fleets/${GAMESERVER_TYPE}/*
do
    envsubst < $f  | kubectl apply --namespace ${NAMESPACE} -f -
done
echo
# echo "- Display fleets and game servers -"
kubectl get fleets --namespace ${NAMESPACE}
kubectl get gameservers --namespace ${NAMESPACE} --show-labels
echo