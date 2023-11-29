
## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0
export CLUSTER_NAME_1="agones-gameservers-1"
export AWS_REGION_1="us-east-1"
# Global Accelerator is a global service that supports endpoints in multiple Amazon Web Services Regions
# but you must specify the US West (Oregon) Region to create, update, or otherwise work with accelerators.
# That is, for example, specify --region us-west-2 on AWS CLI commands.
# (https://awscli.amazonaws.com/v2/documentation/api/latest/reference/globalaccelerator/index.html)
export AWS_REGION="us-west-2"
AWS_ACCOUNT=$(aws sts get-caller-identity --query "Account" --output text)

echo "- Fetching cluster 1 Load Balancer address -"
kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER_NAME_1})
FRONTEND_1=$(kubectl get svc -n open-match open-match-frontend-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "- Create accelerator -"
GLOBAL_ACCELERATOR_ARN=$(aws globalaccelerator create-accelerator \
  --name agones-openmatch \
  --query "Accelerator.AcceleratorArn" \
  --output text)
echo "- Create listeners -"
GLOBAL_ACCELERATOR_LISTERNER_ARN=$(aws globalaccelerator create-listener \
  --accelerator-arn $GLOBAL_ACCELERATOR_ARN \
  --region $AWS_REGION \
  --protocol TCP \
  --port-ranges FromPort=50504,ToPort=50504 \
  --query "Listener.ListenerArn" \
  --output text)
echo "- Wait until Load Balancer is active -"
aws elbv2 wait load-balancer-available \
  --load-balancer-arns $(aws elbv2 describe-load-balancers \
    --region $AWS_REGION_1 \
    --query "LoadBalancers[?contains(DNSName, '$FRONTEND_1')].LoadBalancerArn" \
    --output text) \
  --region $AWS_REGION_1
  --region $AWS_REGION_2
echo "- Create endpoints -"
ENDPOINTGROUPARN_1=$(aws globalaccelerator create-endpoint-group \
  --region $AWS_REGION \
  --listener-arn $GLOBAL_ACCELERATOR_LISTERNER_ARN \
  --endpoint-group-region $AWS_REGION_1 \
  --query "EndpointGroup.EndpointGroupArn" \
  --output text \
  --endpoint-configurations EndpointId=$(aws elbv2 describe-load-balancers \
    --region $AWS_REGION_1 \
    --query "LoadBalancers[?contains(DNSName, '$FRONTEND_1')].LoadBalancerArn" \
    --output text),Weight=128)
echo "Global Accelerator address: $GLOBAL_ACCELERATOR_ADDR"