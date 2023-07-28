
# set -o xtrace
echo "#####"
aws eks update-kubeconfig --name $1 --region $2
#eksctl create iamidentitymapping --cluster $1 --arn $(aws sts get-caller-identity --query Arn --output text) --group system:masters --region $2
echo "- Verify that the cert-manager pods are running -"
kubectl get pods -n cert-manager -o wide
echo "- Creating namespaces for agones and open match integration -"
kubectl create namespace agones-system
kubectl create namespace open-match
kubectl create namespace agones-openmatch
kubectl create namespace gameservers
echo "- Verify the cert-manager webhook is available -"
kubectl wait deployment -l app=webhook --for condition=Available=True --timeout=90s -n cert-manager
echo "- Create the cluster issuer and the certificate for Agones -"
kubectl apply -f ../../manifests/cluster-issuer.yaml
kubectl apply -f ../../manifests/agones-controller-cert.yaml

sleep 60