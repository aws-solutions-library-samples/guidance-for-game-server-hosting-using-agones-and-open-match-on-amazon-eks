## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
set -o xtrace
echo "#####"
CLUSTER_NAME=$1
ROOT_PATH=$2
kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER_NAME})
kubectl get pods -n open-match -o wide
# Create Load Balancer
kubectl expose deployment open-match-frontend  -n open-match  --type=LoadBalancer  --name="${CLUSTER_NAME}-om-fe"
# Add annotations to create the LB as an internet facing NLB (to be accessed by the clients and used with Global Accelerator)
kubectl annotate svc ${CLUSTER_NAME}-om-fe service.beta.kubernetes.io/aws-load-balancer-scheme=internet-facing -n open-match
kubectl annotate svc ${CLUSTER_NAME}-om-fe service.beta.kubernetes.io/aws-load-balancer-type=nlb --overwrite=true -n open-match

# Create a certificate for open-match
kubectl apply -f ${ROOT_PATH}/manifests/open-match-tls-certmanager.cert.yaml

# Modify the secrets open-match-tls-rootca and open-match-tls-server installed by helm with the values from open-match-tls-certmanager
TLS_CA_VALUE=$(kubectl get secret open-match-tls-certmanager -n open-match -ojsonpath='{.data.ca\.crt}')
TLS_CERT_VALUE=$(kubectl get secret open-match-tls-certmanager -n open-match -ojsonpath='{.data.tls\.crt}')
TLS_KEY_VALUE=$(kubectl get secret open-match-tls-certmanager -n open-match -ojsonpath='{.data.tls\.key}')
kubectl get secret open-match-tls-rootca -o json -n open-match | jq '.data["public.cert"]="'${TLS_CA_VALUE}'"' | kubectl apply -f -
kubectl get secret open-match-tls-server -o json -n open-match | jq '.data["public.cert"]="'${TLS_CERT_VALUE}'"' | kubectl apply -f -
kubectl get secret open-match-tls-server -o json -n open-match | jq '.data["private.key"]="'${TLS_KEY_VALUE}'"' | kubectl apply -f -

# Restart open-match pods to use the new certificate
kubectl delete pods -n open-match --all

# Copy the open-match-tls-certmanager from open-match to agones-openmatch namespace
kubectl get secret open-match-tls-certmanager -o json -n open-match | jq '.metadata.namespace="agones-openmatch"' | kubectl apply -f -
