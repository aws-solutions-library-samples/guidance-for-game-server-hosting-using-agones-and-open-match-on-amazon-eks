export CLUSTER_NAME=$1
export AWS_REGION=$2
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}
KEY_FILE=client_${CLUSTER_NAME}.key
CERT_FILE=client_${CLUSTER_NAME}.crt
TLS_CA_FILE=ca_${CLUSTER_NAME}.crt
kubectl get secret allocator-client.default -n default -o jsonpath="{.data.tls\.crt}" | base64 -d > "${CERT_FILE}"
kubectl get secret allocator-client.default -n default -o jsonpath="{.data.tls\.key}" | base64 -d > "${KEY_FILE}"
kubectl get secret allocator-tls-ca -n agones-system -o jsonpath="{.data.tls-ca\.crt}" | base64 -d > "${TLS_CA_FILE}"
EXTERNAL_IP=$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
ENDPOINT=https://${EXTERNAL_IP}/gameserverallocation
curl ${ENDPOINT} --key ${KEY_FILE} --cert ${CERT_FILE} --cacert ${TLS_CA_FILE} -H "Content-Type: application/json" --data '{"namespace":"'${NAMESPACE}'"}'