# set -o xtrace
echo "#####"
NAMESPACE=agones-system
GAMESERVER_NAMESPACE=gameservers
CLUSTER_NAME1=$1
AWS_REGION1=$2
CLUSTER_NAME2=$3
AWS_REGION2=$4
KEY_FILE=client_${CLUSTER_NAME1}.key
CERT_FILE=client_${CLUSTER_NAME1}.crt
TLS_CA_FILE=ca_${CLUSTER_NAME1}.crt
aws eks update-kubeconfig --name ${CLUSTER_NAME1} --region ${AWS_REGION1}
EXTERNAL_IP=$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
ENDPOINT=https://${EXTERNAL_IP}/gameserverallocation
echo "- Allocating server -"
curl ${ENDPOINT} --key ${KEY_FILE} --cert ${CERT_FILE} --cacert ${TLS_CA_FILE} -H "Content-Type: application/json" --data '{"namespace":"'${NAMESPACE}'", "multiClusterSetting":{"enabled":true}}'
echo
echo "- Display ALLOCATED game servers on cluster ${CLUSTER_NAME1} only -"
kubectl get gameservers --namespace ${GAMESERVER_NAMESPACE} | grep Allocated
aws eks update-kubeconfig --name ${CLUSTER_NAME2} --region ${AWS_REGION2}
echo "- Display ALLOCATED game servers on cluster ${CLUSTER_NAME2} only -"
kubectl get gameservers --namespace ${GAMESERVER_NAMESPACE} | grep Allocated
