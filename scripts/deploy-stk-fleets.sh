## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
export GAMESERVER_TYPE=stk 
export NAMESPACE=gameservers
export CLUSTER_NAME1=$1
export REGION1=$2
export CLUSTER_NAME2=$3
export REGION2=$4
export ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
export REGISTRY=${ACCOUNT_ID}.dkr.ecr.${REGION1}.amazonaws.com
export ARCHITECTURE=$5

echo "Fetching necessary files"
mkdir integration/clients/stk-server-build
curl -L -o integration/clients/stk-server-build/Dockerfile https://raw.githubusercontent.com/googleforgames/agones/refs/heads/main/examples/supertuxkart/Dockerfile
curl -L -o integration/clients/stk-server-build/entrypoint.sh https://raw.githubusercontent.com/googleforgames/agones/refs/heads/main/examples/supertuxkart/entrypoint.sh
curl -L -o integration/clients/stk-server-build/go.mod https://raw.githubusercontent.com/googleforgames/agones/refs/heads/main/examples/supertuxkart/go.mod
curl -L -o integration/clients/stk-server-build/go.sum https://raw.githubusercontent.com/googleforgames/agones/refs/heads/main/examples/supertuxkart/go.sum
curl -L -o integration/clients/stk-server-build/server_config.xml https://raw.githubusercontent.com/googleforgames/agones/refs/heads/main/examples/supertuxkart/server_config.xml
curl -L -o integration/clients/stk-server-build/main.go https://raw.githubusercontent.com/googleforgames/agones/refs/heads/main/examples/supertuxkart/main.go

echo "- Creating tailored supertuxkart image (amd64 or arm64) -"
aws ecr get-login-password --region ${REGION1} | docker login --username AWS --password-stdin $REGISTRY

if [[ $ARCHITECTURE == "arm64" ]];
then 
  echo "building arm64 version";
  docker buildx build --platform=linux/arm64  -t $REGISTRY/supertuxkart-server integration/clients/stk-server-build
else 
  echo "building amd64 version";
  docker buildx build --platform=linux/amd64  -t $REGISTRY/supertuxkart-server integration/clients/stk-server-build
fi

docker push $REGISTRY/supertuxkart-server

echo "supertuxkart build and push was successful"

echo "- Deploy fleets to cluster ${CLUSTER_NAME1} -"
kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER_NAME1})
export REGION=$REGION1
for f in manifests/fleets/${GAMESERVER_TYPE}/*
do
    envsubst < $f  | kubectl apply --namespace ${NAMESPACE} -f -
done
echo
echo "- Display fleets and game servers -"
kubectl get fleets --namespace ${NAMESPACE}
kubectl get gameservers --namespace ${NAMESPACE} --show-labels
echo


echo "- Deploy fleets to cluster ${CLUSTER_NAME2} -"
kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER_NAME2})
export REGION=$REGION2
for f in manifests/fleets/${GAMESERVER_TYPE}/*
do
    envsubst < $f  | kubectl apply --namespace ${NAMESPACE} -f -
done
echo
# echo "- Display fleets and game servers -"
kubectl get fleets --namespace ${NAMESPACE}
kubectl get gameservers --namespace ${NAMESPACE} --show-labels
echo
