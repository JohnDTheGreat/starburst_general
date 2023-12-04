#!/bin/bash

# This script will gather logs from all pods in a given namespace and context
# It will then tar and gzip the logs and place them in the current directory

# Initialize variables
K8CONTEXT=""
K8NAMESPACE=""
# For testing
K8CONTEXT="aws"
K8NAMESPACE="default"

#Get input from command line options to set variables
while getopts ":c:n:" opt; do
  case $opt in
    c) K8CONTEXT="$OPTARG"
    ;;
    n) K8NAMESPACE="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

# Check if variables are set
if [ -z "$K8CONTEXT" ]; then
  echo "kubernetes context is unset"
  echo "Please enter a context with the -c option"
  exit 1
fi

if [ -z "$K8NAMESPACE" ]; then
  echo "kubernetes namespace is unset"
  echo "Please enter a namespace with the -n option"
  exit 1
fi

# Function for printing message to stdout with preceding timestamp
function print_msg {
  printf "$(date +%Y-%m-%d" "%H:%M:%S) $1\n"
}

# Create directory to store bundle with K8NAMESPACE and K8CONTEXT and timestamp
# Include directories for pods, deployments, services, secrets, configmaps, nodes and other
print_msg "Creating bundle directory"
BUNDLE="namespace-$K8NAMESPACE"'_'"context-$K8CONTEXT"'_'"$(date +%Y-%m-%d_%H-%M-%S)"
PODDIR="$BUNDLE/pods"
DEPLOYDIR="$BUNDLE/deployments"
SERVICEDIR="$BUNDLE/services"
SECRETSDIR="$BUNDLE/secrets"
CONFIGMAPSDIR="$BUNDLE/configmaps"
NODEDIR="$BUNDLE/nodes"
OTHER="$BUNDLE/other"
LOGDIR="$BUNDLE/logs"
print_msg "Bundle directory is: $BUNDLE"
mkdir $BUNDLE $PODDIR $DEPLOYDIR $SERVICEDIR $SECRETSDIR $CONFIGMAPSDIR $NODEDIR $OTHER $LOGDIR

# Section for getting other meta information
print_msg "Getting other meta information"
kubectl version --context $K8CONTEXT &> $OTHER/kubectl_version.$K8CONTEXT.out
kubectl cluster-info --context $K8CONTEXT &> $OTHER/kubectl_cluster_info.$K8CONTEXT.out
kubectl get events --context $K8CONTEXT &> $OTHER/kubectl_get_events.$K8CONTEXT.out
kubectl get componentstatuses --context $K8CONTEXT &> $OTHER/kubectl_get_componentstatuses.$K8CONTEXT.out
kubectl get all -o custom-columns=Kind:.kind,Name:.metadata.name,Finalizers:.metadata.finalizers \
--all-namespaces --context $K8CONTEXT &> $OTHER/kubectl_finalizers.$K8CONTEXT.out

# Get pods, deployments, services, secrets, configmaps, and nodes in context and namespace
print_msg "Getting pods, deployments, services, secrets, configmaps, and nodes in context and namespace"
PODS=$(kubectl get pods -n $K8NAMESPACE --context $K8CONTEXT | awk 'NR>1 {print $1}')
DEPLOYMENTS=$(kubectl get deployments -n $K8NAMESPACE --context $K8CONTEXT | awk 'NR>1 {print $1}')
SERVICES=$(kubectl get services -n $K8NAMESPACE --context $K8CONTEXT | awk 'NR>1 {print $1}')
SECRETS=$(kubectl get secrets -n $K8NAMESPACE --context $K8CONTEXT | awk 'NR>1 {print $1}')
CONFIGMAPS=$(kubectl get configmaps -n $K8NAMESPACE --context $K8CONTEXT | awk 'NR>1 {print $1}')
NODES=$(kubectl get nodes --context $K8CONTEXT | awk 'NR>1 {print $1}')

# Get kubectl get output for pods, deployments, services, secrets, configmaps, and nodes
print_msg "Getting kubectl get output for pods, deployments, services, secrets, configmaps, and nodes"
kubectl get pods -n $K8NAMESPACE --context $K8CONTEXT -o wide &> $PODDIR/kubectl_get_pods.namespace-$K8NAMESPACE.context-$K8CONTEXT.out
kubectl get deployments -n $K8NAMESPACE --context $K8CONTEXT -o wide &> $DEPLOYDIR/kubectl_get_deployments.namespace-$K8NAMESPACE.context-$K8CONTEXT.out
kubectl get services -n $K8NAMESPACE --context $K8CONTEXT -o wide &> $SERVICEDIR/kubectl_get_services.namespace-$K8NAMESPACE.context-$K8CONTEXT.out
kubectl get secrets -n $K8NAMESPACE --context $K8CONTEXT -o wide &> $SECRETSDIR/kubectl_get_secrets.namespace-$K8NAMESPACE.context-$K8CONTEXT.out
kubectl get configmaps -n $K8NAMESPACE --context $K8CONTEXT -o wide &> $CONFIGMAPSDIR/kubectl_get_configmaps.namespace-$K8NAMESPACE.context-$K8CONTEXT.out
kubectl get nodes --context $K8CONTEXT -o wide &> $NODEDIR/kubectl_get_nodes.context-$K8CONTEXT.out

# Get kubectl describe and yaml output for pods, deployments, services, secrets, configmaps, and nodes individually
# PODS
print_msg "Getting describes and yaml for pods"
for pod in $PODS
do
  kubectl describe pod $pod -n $K8NAMESPACE --context $K8CONTEXT \ 
  &> $PODDIR/kubectl_describe_pod.$pod.namespace-$K8NAMESPACE.context-$K8CONTEXT.out
  kubectl get pod $pod -n $K8NAMESPACE --context $K8CONTEXT -o yaml \
  &> $PODDIR/kubectl_get_pod.$pod.namespace-$K8NAMESPACE.context-$K8CONTEXT.yaml
done
# DEPLOYMENTS
print_msg "Getting describes and yaml for deployments"
for deployment in $DEPLOYMENTS
do
  kubectl describe deployment $deployment -n $K8NAMESPACE --context $K8CONTEXT \
  &> $DEPLOYDIR/kubectl_describe_deployment.$deployment.namespace-$K8NAMESPACE.context-$K8CONTEXT.out
  kubectl get deployment $deployment -n $K8NAMESPACE --context $K8CONTEXT -o yaml \
  &> $DEPLOYDIR/kubectl_get_deployment.$deployment.namespace-$K8NAMESPACE.context-$K8CONTEXT.yaml
done
# SERVICES
print_msg "Getting describes and yaml for services"
for service in $SERVICES
do
  kubectl describe service $service -n $K8NAMESPACE --context $K8CONTEXT \
  &> $SERVICEDIR/kubectl_describe_service.$service.namespace-$K8NAMESPACE.context-$K8CONTEXT.out
  kubectl get service $service -n $K8NAMESPACE --context $K8CONTEXT -o yaml \
  &> $SERVICEDIR/kubectl_get_service.$service.namespace-$K8NAMESPACE.context-$K8CONTEXT.yaml
done
# SECRETS
print_msg "Getting describes and yaml for secrets"
for secret in $SECRETS
do
  kubectl describe secret $secret -n $K8NAMESPACE --context $K8CONTEXT \
  &> $SECRETSDIR/kubectl_describe_secret.$secret.namespace-$K8NAMESPACE.context-$K8CONTEXT.out
  kubectl get secret $secret -n $K8NAMESPACE --context $K8CONTEXT -o yaml \
  &> $SECRETSDIR/kubectl_get_secret.$secret.namespace-$K8NAMESPACE.context-$K8CONTEXT.yaml
done
# CONFIGMAPS
print_msg "Getting describes and yaml for configmaps"
for configmap in $CONFIGMAPS
do
  kubectl describe configmap $configmap -n $K8NAMESPACE --context $K8CONTEXT \
  &> $CONFIGMAPSDIR/kubectl_describe_configmap.$configmap.namespace-$K8NAMESPACE.context-$K8CONTEXT.out
  kubectl get configmap $configmap -n $K8NAMESPACE --context $K8CONTEXT -o yaml \
  &> $CONFIGMAPSDIR/kubectl_get_configmap.$configmap.namespace-$K8NAMESPACE.context-$K8CONTEXT.yaml
done
# NODES
print_msg "Getting describes and yaml for nodes"
for node in $NODES
do
  kubectl describe node $node --context $K8CONTEXT \
  &> $NODEDIR/kubectl_describe_node.$node.context-$K8CONTEXT.out
  kubectl get node $node --context $K8CONTEXT -o yaml \
  &> $NODEDIR/kubectl_get_node.$node.context-$K8CONTEXT.yaml
done

# # For testing
# PODS="coordinator-9b999cd76-tz9mf worker-5d58dd7855-7m2nr"

print_msg "Pods we will be collecting information against: \n$PODS"

# Loop through pods and get container names then get logs for each container
for pod in $PODS
do
  print_msg "Getting logs for pod: \n$pod"
  CONTAINERS=$(kubectl get pods $pod -n $K8NAMESPACE --context $K8CONTEXT -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}')
  print_msg "Containers in pod $pod:"
  for container in $CONTAINERS 
  do
    print_msg "$container"
  done
  for container in $CONTAINERS
  do
    print_msg "Getting logs for container: \n$container"
    FILENAME="$pod-$container.$(date +%Y-%m-%d_%H-%M-%S).log"
    kubectl logs $pod -n $K8NAMESPACE -c $container --context $K8CONTEXT &> $LOGDIR/$FILENAME
    print_msg "Log collected for container: $container and saved to: $LOGDIR/$FILENAME"
  done
done 










