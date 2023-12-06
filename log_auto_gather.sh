#!/bin/bash

# This script will gather logs from pods, services, deployments, secrets, configmaps, and nodes
# It will also get information about docker containers
# It will then tar and gzip the logs and place them in the current directory



# Initialize variables
K8CONTEXT=""
K8NAMESPACE=""
CONTAINERID=""
DOCKERCOLLECT="false"
DOCKERCOLLECTFILE="false"
# For testing
# K8CONTEXT="aws"
# K8NAMESPACE="default"

# Create variable for usage
__usage="
Usage: $0 [OPTIONS]

Options:
  -c,  --context                kubectl context optional
  -n,  --namespace              kubectl namespace optional
  -h,  --help                   print this help message
  -d,  --docker                 enabled docker log collection using docker logs
  -f,  --dockerfile             enabled docker log collection using docker inspect
  -i,  --containerid            docker container id optional
"

# Check if arguments are given if not print usage and exit
if [ $# -eq 0 ]; then
  echo "$__usage"
  exit 1
fi

# Get input from short and long command line options to set variables
# If no input is given for context or namespace then the current context and namespace will be used
while [ "$1" != "" ]; do
  case $1 in
    -c | --context )            shift
                                K8CONTEXT=$1
                                ;;
    -n | --namespace )          shift
                                K8NAMESPACE=$1
                                ;;
    -d | --docker )             DOCKERCOLLECT="true"
                                ;;
    -f | --dockerfile )         DOCKERCOLLECTFILE="true"
                                ;;
    -i | --containerid )        shift
                                CONTAINERID=$1
                                ;;
    -h | --help )               echo "$__usage"
                                exit 1
                                ;;
    * )                         echo "Invalid syntax"; echo "$__usage"
                                exit 1
  esac
  shift
done


# # Get input from command line options to set variables
# while getopts ":c:n:h:d:f:i" opt; do
#   case $opt in
#     c) K8CONTEXT="$OPTARG"
#     ;;
#     n) K8NAMESPACE="$OPTARG"
#     ;;
#     d) DOCKERCOLLECT="true"
#     ;;
#     f) DOCKERCOLLECTFILE="true"
#     ;;
#     i) CONTAINERID="$OPTARG"
#     ;;
#     h) echo "$__usage"
#     exit 1
#     ;;
#     \?) echo "Invalid option -$OPTARG" >&2
#     echo "$__usage"
#     exit 1
#     ;;
#   esac
# done

# Check if kubeconfig is set if not set to default
if [ -z "$K8CONTEXT" ]; then
  K8CONTEXT=$(kubectl config current-context)
  echo "kubernetes context not set, using current context: $K8CONTEXT"
fi

if [ -z "$K8NAMESPACE" ]; then
  K8NAMESPACE="default"
  echo "kubernetes namespace not set, using namespace: $K8NAMESPACE"
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
DOCKERDIR="$BUNDLE/docker"
print_msg "Bundle directory is: $BUNDLE"
mkdir $BUNDLE $PODDIR $DEPLOYDIR $SERVICEDIR $SECRETSDIR $CONFIGMAPSDIR $NODEDIR $OTHER $LOGDIR

# Check if DOCKERCOLLECT and DOCKERCOLLECTFILE are both set to true if so default to DOCKERCOLLECT
if [ "$DOCKERCOLLECT" == "true" ] && [ "$DOCKERCOLLECTFILE" == "true" ]; then
  print_msg "Both docker logs and docker file options were used, defaulting to docker logs option"
  DOCKERCOLLECTFILE="false"
fi

# Check if docker option was used and if container id is set if not collect logs from all containers
# Use docker logs command to get logs from container and save to file
if [ "$DOCKERCOLLECT" == "true" ]; then
  print_msg "docker option was used"
  # Add docker directory to bundle
  mkdir $DOCKERDIR
  # Check if container id is set if it is collect logs from that container if not collect logs from all containers
  if [ -z "$CONTAINERID" ]; then
    print_msg "docker container id is unset, will collect docker logs from all containers"
    CONTAINERID=$(docker ps -q)
    print_msg "docker container ids: \n$CONTAINERID"
    for container in $CONTAINERID
    do
      print_msg "Getting docker logs for container: $container"
      FILENAME="$container.$(date +%Y-%m-%d_%H-%M-%S).log"
      docker logs $container &> $DOCKERDIR/$FILENAME
      print_msg "Docker logs collected for container: $container and saved to: $DOCKERDIR/$FILENAME"
    done
  fi
  if [ -n "$CONTAINERID" ]; then
    print_msg "docker container id is set, will collect docker logs from container: $CONTAINERID"
    FILENAME="$CONTAINERID.$(date +%Y-%m-%d_%H-%M-%S).log"
    docker logs $CONTAINERID &> $DOCKERDIR/$FILENAME
    print_msg "Docker logs collected for container: $CONTAINERID and saved to: $DOCKERDIR/$FILENAME"
  fi
fi

# Check if docker option was used and if container id is set if not collect logs from all containers
# Use docker inspect command to get log path and copy the log file to the bundle directory
if [ "$DOCKERCOLLECTFILE" == "true" ]; then
  print_msg "docker option was used"
  # Add docker directory to bundle
  mkdir $DOCKERDIR
  # Check if container id is set if it is collect logs from that container if not collect logs from all containers
  if [ -z "$CONTAINERID" ]; then
    print_msg "docker container id is unset, will collect docker logs from all containers"
    CONTAINERID=$(docker ps -q)
    print_msg "docker container ids: \n$CONTAINERID"
    for container in $CONTAINERID
    do
      print_msg "Getting docker logs for container: $container"
      FILENAME="$container.$(date +%Y-%m-%d).log"
      LOGPATH=$(docker inspect -f {{.LogPath}} $container)
      cp $LOGPATH $DOCKERDIR/$FILENAME
      print_msg "Docker logs collected for container: $container and saved to: $DOCKERDIR/$FILENAME"
    done
  fi
  if [ -n "$CONTAINERID" ]; then
    print_msg "docker container id is set, will collect docker logs from container: $CONTAINERID"
    FILENAME="$CONTAINERID.$(date +%Y-%m-%d).log"
    LOGPATH=$(docker inspect -f {{.LogPath}} $CONTAINERID)
    cp $LOGPATH $DOCKERDIR/$FILENAME
    print_msg "Docker logs collected for container: $CONTAINERID and saved to: $DOCKERDIR/$FILENAME"
  fi
fi

# Section for getting other meta information
print_msg "Getting other meta information"
kubectl version --context $K8CONTEXT &> $OTHER/kubectl_version.$K8CONTEXT.out
kubectl cluster-info --context $K8CONTEXT &> $OTHER/kubectl_cluster_info.$K8CONTEXT.out
kubectl get events --context $K8CONTEXT -A &> $OTHER/kubectl_get_events.$K8CONTEXT.out
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
  print_msg "Getting logs for pod: $pod"
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

# Tar and gzip bundle directory
print_msg "Tarring and gzipping bundle directory"
tar -czvf $BUNDLE.tar.gz $BUNDLE
print_msg "Bundle is packaged as file: $BUNDLE.tar.gz"










