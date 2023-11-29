## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
sleep 3
NAMESPACE=$1
kubectl get namespace ${NAMESPACE} && kubectl get namespace ${NAMESPACE} -o json | jq 'del(.spec.finalizers[0])' | kubectl replace --raw "/api/v1/namespaces/${NAMESPACE}/finalize" -f -

