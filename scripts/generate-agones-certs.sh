## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
set -o xtrace
echo "#####"
CLUSTER_NAME=$1
ROOT_PATH=$2
kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER_NAME})
echo "- Verify that the cert-manager pods are running -"
kubectl get pods -n cert-manager -o wide
echo "- Verify the cert-manager webhook is available -"
kubectl wait deployment -l app=webhook --for condition=Available=True --timeout=90s -n cert-manager
echo "- Create the cluster issuer and the certificate for Agones -"
kubectl apply -f ${ROOT_PATH}/manifests/cluster-issuer.yaml
kubectl apply -f ${ROOT_PATH}/manifests/agones-controller-cert.yaml

sleep 60