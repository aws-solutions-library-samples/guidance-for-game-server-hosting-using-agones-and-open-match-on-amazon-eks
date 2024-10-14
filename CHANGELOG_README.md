## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0

# Description
Running log of recent changes, on a git commit level. The purpose of this document is to provide more details about changes to the project without having overly verbose commit messages.

# Change Log
## 10-11-2024
**TLDR;** Wrapped up all SuperTuxKart changes so it now works with Arm-based instances. Running the game with AI racers has not been tested yet.

- Updated the node affinity attributes of SuperTuxKart's manifest files to have the appropriate agones servers launched in the gameserver Managed Node Group.
- Increased the minimum number of nodes for the Agones Managed Node Group to 3 for adequate storage (EBS volumes) for all required workloads.
- Incorporated commands in `deploy-stk-fleets.sh` script to download the necessary files to build an arm-based version of SuperTuxKart for Agones.
- Created an immutable ECR Repository for SuperTuxKart arm-based image to be stored and pulled when needed
- Added pod anti-affinity for the agones controller to improve reliability
- Configured helm values for agones helm chart to add node selector terms to appropriate pods launched by the helm chart
- Updated README.md for SuperTuxKart example
- Updated general README.md

## 9-2-2024
**TLDR;** Modified ncat gameservers to have the ability to run with arm-based containers. Made ECR repos mutable. Added arm-arch node affinity to /integration/director/director.yaml and /integration/matchfunction/matchfunction.yaml.

- Modified the /scripts/deploy-ncat-fleets.sh file to be able to build ncat servers for the linux/arm64 platform. The deployer can specify which architecture to use in the script by running the command found in the README.md file.
- Set the agones-openmatch-ncat-server ECR repository to be mutable for the scripts/deploy-ncat-fleets.sh script to push the correct images to the repository. There was an error with the script trying to push an image to the repository when it was first created. The change permits the solution to upload an image index artifact to ECR. Otherwise, only the image gets uploaded. This does open things up for people to push editions of the same version/tag of an image in an image repository.
- Added node affinity for matchfunction and director yaml files in integration/director and integration.matchfunction directories. The node affinity assigns the pods to x86-based nodes.
- Updated the README.md file to have more efficient deletion commands and clearer instructions when choosing between arm-based and x86-based instance architectures.


## 8-27-2024
**TLDR;** Improved the readability of the terraform/cluster section of the README.md file. Improved the markdown formatting of the CHANGELOG_README.md file. Removed functionality for deploying arm-based nodes for openmatch. Fluentbit now creates whatever CloudWatch Log Groups it needs upon deployment. Fixed the README.md file's instructions for fetching the load balancer arn.

- Commented out CLI options to use arm-based instances for openmatch and agones-openmatch MNGs since openmatch containers work only on x86 architectures.
- Commented out variables and if-else statements that enable using arm-based instances with openmatch.
- Modified terraform/intra-cluster/main.tf to have fluentbit create CloudWatch log groups that it needs to successfuly run in the cluster. The log groups are made only if they don't already exist.
- Modified open match load balancer fetch command to more accurately reflect the load balancer's correct name; it's not `open-match-frontend-loadbalancer`, it's `agones-gameservers-1-om-fe`. We could possibly change this in the future...
- Also, it appears that the terraform/extra-cluster command in the README.md file still prompts the user for the load balancer arn even though the environment variable is set. All other variables are fine though... Fixed this typo (was missing a backslash)

```
# Initialize Terraform
terraform -chdir=terraform/cluster init &&
# Create both clusters
terraform -chdir=terraform/cluster apply -auto-approve \
 -var="cluster_1_name=${CLUSTER1}" \
 -var="cluster_1_region=${REGION1}" \
 -var="cluster_1_cidr=${CIDR1}" \
 -var="cluster_2_name=${CLUSTER2}" \
 -var="cluster_2_region=${REGION2}" \
 -var="cluster_2_cidr=${CIDR2}" \
 -var="cluster_version=${VERSION}" \
 -var="all_arm_based_instances_cluster_1"=false \
 -var="all_arm_based_instances_cluster_2"=false \
 -var="gameservers_arm_based_instances_cluster_1"=true \
 -var="gameservers_arm_based_instances_cluster_2"=true \
 -var="agones_system_arm_based_instances_cluster_1"=true \
 -var="agones_system_arm_based_instances_cluster_2"=true \
 -var="agones_metrics_arm_based_instances_cluster_1"=true \
 -var="agones_metrics_arm_based_instances_cluster_2"=true
```



## 8-13-2024
**TLDR;** Added more flexibility for choosing which Managed Node Groups (MNGs) can have which architecture. The deployer can have 1, all, none, or any number in between of MNGs using an arm-based architecture. The deployer can also specify which MNG in which cluster should have which architecture type.

- Added new variables to both of the terraform variables files int he core EKS Cluster (/terraform/cluster/variables.tf & /terraform/cluster/modules/cluster/variables.tf). Also added new variable parameters to the EKS modules listed in the main terraform template (/terraform/cluster/main.tf). These new variables enable deployers to specify which Managed Node Groups (MNGs) should have x86 or arm-based instances. There is also an option to have all MNGs in a cluster have either x86 or arm-based instances.
- Modified the EKS Module terraform file (/terraform/cluster/modules/cluster/main.tf) so that the new variables impact what architecture the nodes in each MNG uses.
- @sdpoueme and I had a discussion about whether to use booleans or a list of MNGs to have arm-based architectures. In the end, we decided on booleans over a list for the sake of intuitiveness. While a more verbose option, it is simpler and faster to implement. Plus, there is less error for typos accidentally attempting to configure non-existent MNGs. With boolean values, terraform will alert the deployer of any typos, stating that the given option does not exist or that the value passed into an option is an invalid boolean value.
- Updated the README.md file to show a more up-to-date option list.
- The new most verbose launch command for the core EKS Cluster through terraform with arm-based instances will be like so:
```
# Initialize Terraform
terraform -chdir=terraform/cluster init &&
# Create both clusters
terraform -chdir=terraform/cluster apply -auto-approve \
 -var="cluster_1_name=${CLUSTER1}" \
 -var="cluster_1_region=${REGION1}" \
 -var="cluster_1_cidr=${CIDR1}" \
 -var="cluster_2_name=${CLUSTER2}" \
 -var="cluster_2_region=${REGION2}" \
 -var="cluster_2_cidr=${CIDR2}" \
 -var="cluster_version=${VERSION}" \
 -var="all_arm_based_instances_cluster_1"=false \
 -var="all_arm_based_instances_cluster_2"=false \
 -var="gameservers_arm_based_instances_cluster_1"=true \
 -var="gameservers_arm_based_instances_cluster_2"=true \
 -var="agones_system_arm_based_instances_cluster_1"=true \
 -var="agones_system_arm_based_instances_cluster_2"=true \
 -var="agones_metrics_arm_based_instances_cluster_1"=true \
 -var="agones_metrics_arm_based_instances_cluster_2"=true \
 -var="open_match_arm_based_instances_cluster_1"=false \
 -var="open_match_arm_based_instances_cluster_2"=false \
 -var="agones_open_match_arm_based_instances_cluster_1"=false \
 -var="agones_open_match_arm_based_instances_cluster_2"=false
```



## 8-8-2024
**TLDR;** Pass in a boolean option when creating the core cluster in the CLI to switch between x86-based and arm-based instances in the cluster's Managed Node Group. The deployer is responsible for ensuring that the non-default instance types in the terraform variables files have the architecture that matches the expectation of the array they are in.

- Added new variables to both of the terraform variables files in the core EKS Cluster (/terraform/cluster/variables.tf & /terraform/cluster/modules/cluster/variables.tf). These new variables enable people to switch between using an array of x86-based instances and an array of arm-based instances for the nodes in the core EKS cluster. A boolean variable was added to the /terraform/cluster/variables.tf file to enable dynamic switching between x86-based instances and arm-based instances in the EKS Module terraform file (/terraform/cluster/modules/cluster/main.tf).
- Modified the EKS Module terraform file (/terraform/cluster/modules/cluster/main.tf) so that based on the boolean option passed into the terraform cluster creation command, either an array of x86-based instance types or an array of arm-based instance types will be used for provisioning nodes in the main Managed Node Group of the core cluster.
- @sdpoueme and I had a discussion about enforcing arm-based and x86-based instance types in the two arrays, but in the end it was decided that it is up to the deployer to ensure that the correct instance types are in their appropriate array. We will ensure that the defaults are always correct.
- The new command for launching the core EKS Cluster through terraform with arm-based instances will be like so:
```
# Initialize Terraform
terraform -chdir=terraform/cluster init &&
# Create both clusters
terraform -chdir=terraform/cluster apply -auto-approve \
 -var="cluster_1_name=${CLUSTER1}" \
 -var="cluster_1_region=${REGION1}" \
 -var="cluster_1_cidr=${CIDR1}" \
 -var="cluster_2_name=${CLUSTER2}" \
 -var="cluster_2_region=${REGION2}" \
 -var="cluster_2_cidr=${CIDR2}" \
 -var="cluster_version=${VERSION}" \
 -var="arm_based_instances"=true
```
- Minor updates to the main README.md file to clarify installation and deployment instructions
- In this commit, all instance and ami types in the core cluster (gameservers, agones, openmatch, etc.) are toggled between x86 and arm architectures through the one option in the cli command (arm_based_instances=true). So all instances and ami's are either arm-based or x86-based.