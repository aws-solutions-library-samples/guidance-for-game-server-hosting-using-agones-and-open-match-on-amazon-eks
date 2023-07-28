aws eks update-kubeconfig --name $1 --region $2 2>&1 > /dev/null
ALLOCATOR_IP=$(kubectl get services agones-allocator -n agones-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo ${ALLOCATOR_IP}
