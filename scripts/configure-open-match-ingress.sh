## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
set -o xtrace
set -e
echo "#####"
CLUSTER_NAME=$1
ROOT_PATH=$2
REGION=$3
CONTEXT=$(kubectl config get-contexts -o=name | grep "/${CLUSTER_NAME}$" | head -1)
if [ -z "$CONTEXT" ]; then
  echo "ERROR: No kubectl context found matching cluster '${CLUSTER_NAME}'." >&2
  kubectl config get-contexts -o=name >&2
  exit 1
fi
kubectl config use-context "$CONTEXT"
kubectl get pods -n open-match -o wide

# Create a certificate for open-match
kubectl apply -f ${ROOT_PATH}/manifests/open-match-tls-certmanager.cert.yaml

# Wait for the certificate secret to be ready
echo "Waiting for open-match-tls-certmanager secret..."
kubectl wait --for=condition=Ready certificate/open-match-tls-certmanager -n open-match --timeout=120s

# Extract certificate from Kubernetes secret
TLS_CA_VALUE=$(kubectl get secret open-match-tls-certmanager -n open-match -ojsonpath='{.data.ca\.crt}')
TLS_CERT_VALUE=$(kubectl get secret open-match-tls-certmanager -n open-match -ojsonpath='{.data.tls\.crt}')
TLS_KEY_VALUE=$(kubectl get secret open-match-tls-certmanager -n open-match -ojsonpath='{.data.tls\.key}')

# Modify the secrets open-match-tls-rootca and open-match-tls-server installed by helm with the values from open-match-tls-certmanager
kubectl get secret open-match-tls-rootca -o json -n open-match | jq '.data["public.cert"]="'${TLS_CA_VALUE}'"' | kubectl apply -f -
kubectl get secret open-match-tls-server -o json -n open-match | jq '.data["public.cert"]="'${TLS_CERT_VALUE}'"' | kubectl apply -f -
kubectl get secret open-match-tls-server -o json -n open-match | jq '.data["private.key"]="'${TLS_KEY_VALUE}'"' | kubectl apply -f -

# Restart open-match pods to use the new certificate
kubectl delete pods -n open-match --all

# Copy the open-match-tls-certmanager from open-match to agones-openmatch namespace
kubectl get secret open-match-tls-certmanager -o json -n open-match | jq '.metadata.namespace="agones-openmatch" | del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp)' | kubectl apply -f -

# Import the certificate into ACM for NLB TLS termination
CERT_TMPDIR=$(mktemp -d)
chmod 700 "${CERT_TMPDIR}"
trap "rm -rf ${CERT_TMPDIR}" EXIT
echo "${TLS_CERT_VALUE}" | base64 -d > "${CERT_TMPDIR}/tls.crt"
echo "${TLS_KEY_VALUE}" | base64 -d > "${CERT_TMPDIR}/tls.key"
echo "${TLS_CA_VALUE}" | base64 -d > "${CERT_TMPDIR}/ca.crt"

ACM_ARN=$(aws acm import-certificate \
  --certificate "fileb://${CERT_TMPDIR}/tls.crt" \
  --private-key "fileb://${CERT_TMPDIR}/tls.key" \
  --certificate-chain "fileb://${CERT_TMPDIR}/ca.crt" \
  --region "${REGION}" \
  --tags Key=Name,Value="${CLUSTER_NAME}-open-match-frontend" \
  --output text --query CertificateArn)

echo "Imported certificate to ACM: ${ACM_ARN}"

# Create Load Balancer with TLS termination
kubectl expose deployment open-match-frontend -n open-match --type=LoadBalancer --name="${CLUSTER_NAME}-om-fe" --port=50504 --target-port=50504 --dry-run=client -o yaml | kubectl apply -f -

# Annotate the service for NLB with TLS termination (AWS Load Balancer Controller)
kubectl annotate svc ${CLUSTER_NAME}-om-fe -n open-match --overwrite=true \
  service.beta.kubernetes.io/aws-load-balancer-type=external \
  service.beta.kubernetes.io/aws-load-balancer-nlb-target-type=ip \
  service.beta.kubernetes.io/aws-load-balancer-scheme=internet-facing \
  service.beta.kubernetes.io/aws-load-balancer-ssl-cert="${ACM_ARN}" \
  service.beta.kubernetes.io/aws-load-balancer-ssl-ports="50504" \
  service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy=ELBSecurityPolicy-TLS13-1-2-Res-2021-06 \
  service.beta.kubernetes.io/aws-load-balancer-backend-protocol=ssl
