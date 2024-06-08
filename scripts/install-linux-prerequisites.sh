# install or upgrade the aws cli
sudo pip uninstall -y awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip
sudo ./aws/install --update
. ~/.bash_profile

# install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv -v /tmp/eksctl /usr/local/bin
eksctl version || ( echo "eksctl not found" && exit 1 )

# "Install kubectl v1.29.2"
sudo curl --silent --location -o /usr/local/bin/kubectl https://dl.k8s.io/release/v1.29.2/bin/linux/amd64/kubectl  > /dev/null
sudo chmod +x /usr/local/bin/kubectl
kubectl version --client=true || ( echo "kubectl not found" && exit 1 )

# install helm
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# install additional tools
sudo yum -y install jq gettext go openssl bash-completion moreutils

# enable bash completion
kubectl completion bash >>  ~/.bash_completion
eksctl completion bash >> ~/.bash_completion
. ~/.bash_completion

# install yq
echo 'yq() {
 docker run --rm -i -v "${PWD}":/workdir mikefarah/yq yq "$@"
}' | tee -a ~/.bashrc && source ~/.bashrc

# make sure all binaries are in the path
for command in kubectl jq envsubst aws eksctl kubectl helm
  do
    which $command &>/dev/null && echo "$command in path" || ( echo "$command NOT FOUND" && exit 1 )
  done

echo 'Prerequisites installed successfully.'
