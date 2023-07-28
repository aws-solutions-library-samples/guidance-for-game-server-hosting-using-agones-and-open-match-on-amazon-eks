# set -o xtrace
echo "#####"
aws eks update-kubeconfig --name $1 --region $2
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[].name}' | cut -f1 -d.)
echo "- Verify that the Agones pods are running -"
kubectl get pods -n agones-system -o wide
export EXTERNAL_IP=$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "- Verify that the cert-manager pods are running -"
kubectl get pods -n cert-manager -o wide
echo "- Create a certificate for agones-allocator -"
envsubst < manifests/agones-allocator-tls.yaml | kubectl apply -f -
echo "- Wait and get the allocator-tls Secret -"
sleep 2
TLS_CA_VALUE=$(kubectl get secret allocator-tls -n agones-system -o jsonpath='{.data.ca\.crt}')
echo "- Add ca.crt to the allocator-tls-ca Secret -"
kubectl get secret allocator-tls-ca -o json -n agones-system | jq '.data["tls-ca.crt"]="'${TLS_CA_VALUE}'"' | kubectl apply -f -