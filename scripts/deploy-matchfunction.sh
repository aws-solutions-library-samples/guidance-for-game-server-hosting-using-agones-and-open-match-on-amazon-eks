## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
export NAMESPACE=agones-openmatch
export CLUSTER_NAME1=$1
export REGION1=$2
export ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export REGISTRY=${ACCOUNT_ID}.dkr.ecr.${REGION1}.amazonaws.com

echo "- Login to ECR registry -"
aws ecr get-login-password --region ${REGION1} | docker login --username AWS --password-stdin $REGISTRY
echo "- Build matchfunction image -"
docker build  -t $REGISTRY/agones-openmatch-mmf integration/matchfunction
echo "- Push image to register -"
docker push $REGISTRY/agones-openmatch-mmf

kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER_NAME1})
echo "- Deploy Open Match mmf to cluster ${CLUSTER_NAME1} -"
envsubst < integration/matchfunction/matchfunction.yaml | kubectl apply --namespace ${NAMESPACE} -f -
echo
echo "- Display Open Match Matchfunction pod -"
sleep 15
kubectl get pods --namespace ${NAMESPACE} -l app=agones-openmatch-mmf