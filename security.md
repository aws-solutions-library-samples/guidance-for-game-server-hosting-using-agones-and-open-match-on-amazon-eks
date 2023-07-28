# Security recommendations
This page provides suggestions of actions that should be taken to make the solution more secure according to AWS best practices.

## Enable control plane logs
A solutions cluster(s) must have control plane logs enabled in order to publish API, audit, controller manager, scheduler or authenticator logs to AWS CloudWatch Logs. You must enable each log type individually to send logs for your cluster.CloudWatch Logs ingestion, archive storage, and data scanning rates apply to enabled control plane logs.

 Use auditing tools, like [kubeaudit](https://github.com/Shopify/kubeaudit).

 ## Create alerts
 Create an alarm to automatically alert you where there is an increase in **403 Forbidden** and **401 Unauthorized** responses, and then use attributes like host, sourceIPs, and k8s_user.username to find out where those requests are coming from.

 - AWS Custom Config Rules for Kubernetes

    *eks-netPolCheck-rule* Checks that there is a network policy defined for each namespace in the cluster

    *eks-privEscalation-rule* Checks that there are no pods running containers with the AllowPrivilege Escalation flag

    *eks-trustedRegCheck-rule* Checks that container images are from trusted sources

## Use AWS KMS for envelope encryption for Kubernetes secrets
With the [KMS plugin for Kubernetes](https://docs.aws.amazon.com/eks/latest/userguide/enable-kms.html), all Kubernetes secrets are stored in etcd in ciphertext instead of plain text and can only be decrypted by the Kubernetes API server.

Recommendations:
- Rotate your secrets periodically
- Use separate namespaces as a way to isolate secrets from different applications
- Use volume mounts instead of environment variables
- Use an external secrets provider (AWS Secret manager or Vault)

## Scan for runtime security vulnerabilities
Runtime security provides active protection for your containers while they're running. The idea is to detect and/or prevent malicious activity from occuring inside the container.
Recommendations:
- Use a 3rd party solution for runtime defense (Aqua/Qualys/Stackrox/Sysdig Secure/Twistlock)
- Use AWS Marketplace solution 
- Use Linux capabilities before writing seccomp policies 
- Use application vulnerability scan in the pipeline and generate a report (CVEs)
- Scan the produced container image
- Don't deploy a container if the image scan result is higher that certain threshold

## Run periodically CIS Benchmarks or other compliance tools against you environment
[kube-bench](https://github.com/aquasecurity/kube-bench) is an open source project that evaluates your cluster against the CIS benchmarks for Kubernetes. The benchmark describes the best practices for securing unmanaged Kubernetes clusters.

## Use a trusted source for 3rd party HelmCharts
Third party hosted HelmChart repositories dynamically loaded in your environment could become compromised or modified unexpectedly, affecting chart availability and integrity. Ensure to use a trusted domain to load HelmChart Library.

## Adopt a process to harden Kubernetes on EKS Cluster and container images
The following items should implement security best practices to secure Kubernetes on EKS Cluster in AWS.

- Cluster Level Configs
- Cluster Access Management
- Worker Node Configuration
- RBAC/ Cluster Authorization
- Workload configs
- Kubernetes Security Features
- Network Controls

## Enable ELB/ALB access logs 
Use access logs to allow customers to analyze traffic patterns and identify and troubleshoot security issues.

## Enable VPC Flow Logs 
VPC Flow Logs capture network flow information for a VPC, subnet, or network interface and stores it in Amazon CloudWatch Logs. Flow log data can help customers troubleshoot network issues; for example, to diagnose why specific traffic is not reaching an instance, which might be a result of overly restrictive security group rules.