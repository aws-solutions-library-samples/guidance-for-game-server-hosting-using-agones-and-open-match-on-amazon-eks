export NAMESPACE=agones-openmatch
export CLUSTER_NAME1=$1
export AWS_REGION1=$2
export ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export REGISTRY=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION1}.amazonaws.com

echo "- Create configmap -"
# Create the configmap that will store the certs/keys used by the Open Match Director to access the 
# Agones Allocator Service (we use the files `client_agones-gameservers-*` and `ca_agones-gameservers-*` 
# with the certificates details created previously). `director` will communicate with Agones `allocator` 
# using the same way we did in our tests with `curl`.  
kubectl create configmap allocator-tls -n agones-openmatch \
--from-file=tls.crt=client_${CLUSTER_NAME}.crt \
--from-file=tls.key=client_${CLUSTER_NAME}.key \
--from-file=ca.crt=ca_${CLUSTER_NAME}.crt

echo "- Login to ECR registry -"
aws ecr get-login-password --region ${AWS_REGION1} | docker login --username AWS --password-stdin $REGISTRY
echo "- Build director image -"
docker build  -t $REGISTRY/agones-openmatch-director integration/director
echo "- Push image to register -"
docker push $REGISTRY/agones-openmatch-director

aws eks update-kubeconfig --name ${CLUSTER_NAME1} --region ${AWS_REGION1}
echo "- Deploy Open Match Director to cluster ${CLUSTER_NAME1} -"
envsubst < integration/director/director.yaml | kubectl apply --namespace ${NAMESPACE} -f -
echo
echo "- Display Open Match Director pod -"
sleep 15
kubectl get pods --namespace ${NAMESPACE} -l app=agones-openmatch-director